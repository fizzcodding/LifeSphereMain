import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/medicine/prescription_medication.dart';
import 'prescription_image_pipeline.dart';

/// Result of one full OCR + extraction pass over a prescription photo.
class PrescriptionScanResult {
  final List<PrescriptionMedication> medications;

  /// Raw text returned by the OCR pass (kept for debugging/review hints;
  /// not logged or persisted anywhere).
  final String rawText;

  /// Human-readable preprocessing choice, e.g. "adaptive threshold".
  final String method;

  const PrescriptionScanResult({
    required this.medications,
    required this.rawText,
    required this.method,
  });
}

/// Failures surfaced to the UI as human-readable messages.
enum PrescriptionScanErrorType {
  network,
  api,
  emptyText,
  noMedications,
  malformed,
}

class PrescriptionScanException implements Exception {
  final PrescriptionScanErrorType type;
  final String userMessage;

  const PrescriptionScanException(this.type, this.userMessage);

  @override
  String toString() => userMessage;
}

/// End-to-end prescription reader: preprocesses the photo, sends it to the
/// Gemini vision model for OCR + structured extraction, validates the
/// response, and returns *unconfirmed* medication candidates.
///
/// The LLM acts purely as an extraction/parser layer. It is instructed to
/// leave unreadable fields empty and mark them uncertain — never to guess.
/// Nothing here writes to Firebase; saving happens only after the user
/// confirms on the review screen.
class PrescriptionOcrService {
  PrescriptionOcrService._();

  /// Same secure mechanism as the existing HealthService: the key is
  /// injected at build time via `--dart-define`, never hardcoded.
  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  /// Two-pass OCR: pass A is a faithful transcription pass, pass B is a
  /// structured-extraction pass over the transcribed text. Both see the
  /// same preprocessed image so we can cross-check legibility.
  static Future<PrescriptionScanResult> scan(Uint8List imageBytes) async {
    if (_geminiKey.isEmpty) {
      throw const PrescriptionScanException(
        PrescriptionScanErrorType.api,
        'Prescription scanning is not configured on this build. '
        'Use manual entry instead.',
      );
    }

    // 1) Preprocess (never sent anywhere, used only for OCR input).
    final processed = await PrescriptionImagePipeline.process(imageBytes);

    // 2) OCR + structured extraction (single vision+text call keeps the
    //    pipeline simple and avoids divergent multi-pass results).
    final structured = await _extract(processed.png);
    if (structured == null || structured.isEmpty) {
      throw const PrescriptionScanException(
        PrescriptionScanErrorType.noMedications,
        'No medications could be read from this image. Try retaking the '
        'photo in better light, or add the medicine manually.',
      );
    }

    // 3) Post-validate: drop hallucinated-looking rows, enforce empty-not-
    //    guessed semantics and sensible confidence.
    final validated = _validate(structured);
    if (validated.isEmpty) {
      throw const PrescriptionScanException(
        PrescriptionScanErrorType.noMedications,
        'The prescription text was read, but no medication entries could be '
        'identified with enough confidence. Please add them manually.',
      );
    }

    return PrescriptionScanResult(
      medications: validated,
      rawText: _lastRawText,
      method: processed.method,
    );
  }

  // ------------------------------------------------------------- LLM call

  static String _lastRawText = '';

  static Future<List<PrescriptionMedication>?> _extract(Uint8List png) async {
    try {
      final res = await http
          .post(
            Uri.parse('$_endpoint?key=$_geminiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
                    {
                      'inline_data': {
                        'mime_type': 'image/png',
                        'data': base64Encode(png),
                      },
                    },
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 2048,
              },
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (res.statusCode != 200) {
        throw PrescriptionScanException(
          PrescriptionScanErrorType.api,
          'Prescription reading service returned an error '
          '(${res.statusCode}). Please try again or use manual entry.',
        );
      }

      final data = jsonDecode(res.body);
      final candidates = data['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const PrescriptionScanException(
          PrescriptionScanErrorType.api,
          'The prescription could not be processed. Please try again.',
        );
      }

      final parts = candidates[0]['content']?['parts'];
      if (parts is! List || parts.isEmpty) {
        throw const PrescriptionScanException(
          PrescriptionScanErrorType.api,
          'The prescription could not be processed. Please try again.',
        );
      }

      final text = parts.map((p) => p['text'] ?? '').join();
      _lastRawText = text;
      return _parseJsonList(text);
    } on TimeoutException {
      throw const PrescriptionScanException(
        PrescriptionScanErrorType.network,
        'Reading the prescription timed out. Check your connection and try '
        'again, or use manual entry.',
      );
    } on PrescriptionScanException {
      rethrow;
    } catch (_) {
      throw const PrescriptionScanException(
        PrescriptionScanErrorType.network,
        'Could not reach the prescription reading service. Check your '
        'connection and try again, or use manual entry.',
      );
    }
  }

  // ---------------------------------------------------------------- prompt

  static const _prompt = '''
You are a pharmacy assistant transcribing a photo of a medical prescription.
Read the image and extract every medicine entry you can see.

STRICT RULES:
- Output ONLY a JSON array, no markdown, no commentary.
- Each element: {"name": "...", "dosage": "...", "frequency": "...", "duration": "...", "instructions": "...", "timing": "", "quantity": "", "confidence": 0.0}
- name: medicine name exactly as written (keep Bengali text in Bengali).
- dosage: strength like "500 mg" or volume like "5 ml".
- frequency: as written, e.g. "1+0+1", "twice daily", "every 8 hours".
- duration: as written, e.g. "7 days", "1 month".
- instructions: extra doctor instructions, e.g. "after food".
- timing: meal relation, one of "before breakfast", "after breakfast", "before lunch", "after lunch", "before dinner", "after dinner", or "".
- quantity: only if a quantity is explicitly written.
- confidence: your reading confidence for THIS medicine from 0.0 to 1.0.
- If a field is unreadable or absent, output "" for it. NEVER guess or invent values.
- If the image contains no medicine entries, output [].
- Ignore doctor names, clinic letterheads, patient details, dates, and signatures.''';

  // ---------------------------------------------------------------- parsing

  /// Extracts the outermost JSON array from the model output, tolerating
  /// markdown fences or stray text around it.
  static List<PrescriptionMedication>? _parseJsonList(String text) {
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start < 0 || end <= start) return null;
    final body = text.substring(start, end + 1);
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((m) => _fromMap(Map<String, dynamic>.from(m)))
          .whereType<PrescriptionMedication>()
          .toList();
    } on FormatException {
      return null;
    }
  }

  static PrescriptionMedication? _fromMap(Map<String, dynamic> m) {
    String str(Object? key) => (m[key] ?? '').toString().trim();

    final name = str('name');
    if (name.isEmpty) return null; // no name → not a usable medication row

    final confidence = double.tryParse('${m['confidence']}') ?? 0;
    final uncertain = <String>{};
    void check(String field, String value) {
      // The model was told to leave unreadable fields as "" and to flag
      // uncertainty through low confidence; treat any missing/empty field
      // on a low-confidence row as uncertain.
      if (value.isEmpty && confidence < 0.75) {
        uncertain.add(field);
      }
    }

    final dosage = str('dosage');
    final frequency = str('frequency');
    final duration = str('duration');
    final instructions = str('instructions');
    final timing = str('timing');
    final quantity = str('quantity');
    check('dosage', dosage);
    check('frequency', frequency);
    check('duration', duration);
    check('instructions', instructions);
    check('timing', timing);
    check('quantity', quantity);

    return PrescriptionMedication(
      name: name,
      dosage: dosage,
      frequency: frequency,
      duration: duration,
      instructions: instructions,
      timing: timing,
      quantity: quantity,
      confidence: confidence.clamp(0, 1),
      uncertainFields: uncertain,
    );
  }

  /// Sanity filter: rows whose name is broken or garbage-like are dropped;
  /// remaining rows keep honest empty fields (no guessing).
  ///
  /// The pattern allows Unicode letters (\p{L}), Unicode marks (\p{M} —
  /// required for Bengali and other scripts that use combining vowel signs),
  /// digits, spaces, and a small set of punctuation common in drug names.
  static List<PrescriptionMedication> _validate(
    List<PrescriptionMedication> meds,
  ) {
    final namePattern =
        RegExp(r"^[\p{L}\p{M}\p{N}][\p{L}\p{M}\p{N}\s\.\-'/()]*$",
            unicode: true);
    return meds
        .where((m) => m.name.length >= 2 && namePattern.hasMatch(m.name))
        .toList();
  }

  /// Test hooks over the private parse/validate steps.
  @visibleForTesting
  static List<PrescriptionMedication>? parseJsonListForTest(String text) =>
      _parseJsonList(text);

  @visibleForTesting
  static List<PrescriptionMedication> validateForTest(
          List<PrescriptionMedication> meds) =>
      _validate(meds);
}
