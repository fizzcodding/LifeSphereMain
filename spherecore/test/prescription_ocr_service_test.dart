import 'package:flutter_test/flutter_test.dart';
import 'package:spherecore/models/medicine/prescription_medication.dart';
import 'package:spherecore/services/prescription/prescription_ocr_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // JSON parsing — original cases (must stay green)
  // ─────────────────────────────────────────────────────────────────────────
  group('prescription OCR JSON parsing — existing cases', () {
    test('parses a clean array', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList('''
        [
          {"name": "Napa", "dosage": "500 mg", "frequency": "1+0+1",
           "duration": "7 days", "instructions": "After food",
           "timing": "after breakfast", "quantity": "14", "confidence": 0.9}
        ]
      ''');
      expect(meds, isNotNull);
      expect(meds!.length, 1);
      final m = meds.first;
      expect(m.name, 'Napa');
      expect(m.dosage, '500 mg');
      expect(m.timing, 'after breakfast');
      expect(m.confidence, 0.9);
      expect(m.uncertainFields, isEmpty);
    });

    test('tolerates markdown fences around the JSON', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '```json\n'
        '[{"name": "Sergel", "dosage": "", "confidence": 0.4}]\n'
        '```',
      );
      expect(meds, isNotNull);
      expect(meds!.first.name, 'Sergel');
    });

    test('unreadable fields on low-confidence rows are flagged uncertain', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Monas", "dosage": "", "confidence": 0.3}]',
      );
      final m = meds!.single;
      expect(m.dosage, isEmpty);
      expect(m.uncertainFields, isNotEmpty);
    });

    test('garbage without a JSON array returns null', () {
      expect(PrescriptionOcrServiceTestAccess.parseList('no json here'), isNull);
    });

    test('array with no valid medication rows yields an empty list', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList('["str"]');
      expect(meds, isNotNull);
      expect(meds, isEmpty);
    });

    test('drops rows without a name', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "", "dosage": "5 mg"}, {"name": "Napa"}]',
      );
      expect(meds!.length, 1);
      expect(meds.first.name, 'Napa');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Validation — original cases
  // ─────────────────────────────────────────────────────────────────────────
  group('prescription OCR validation — existing cases', () {
    test('filters garbage names', () {
      final meds = [
        PrescriptionMedication(name: 'Napa'),
        PrescriptionMedication(name: 'x'),
        PrescriptionMedication(name: '!!!!'),
        PrescriptionMedication(name: 'Maxpro 20'),
      ];
      final ok = PrescriptionOcrServiceTestAccess.validate(meds);
      expect(ok.map((m) => m.name), ['Napa', 'Maxpro 20']);
    });
  });

  test('model flags empty rows', () {
    expect(PrescriptionMedication(name: '').isCompletelyEmpty, isTrue);
    expect(
      PrescriptionMedication(name: '', dosage: '5 mg').isCompletelyEmpty,
      isFalse,
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Multiple medicines in one OCR result
  // ─────────────────────────────────────────────────────────────────────────
  group('multiple medicines in OCR output', () {
    test('all valid medicines survive parsing', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList('''
        [
          {"name": "Napa", "dosage": "500 mg", "frequency": "1+0+1",
           "confidence": 0.92},
          {"name": "Sergel", "dosage": "20 mg", "frequency": "OD",
           "confidence": 0.88},
          {"name": "Monas", "dosage": "10 mg", "frequency": "Once daily",
           "confidence": 0.85}
        ]
      ''');
      expect(meds, isNotNull);
      expect(meds!.length, 3);
      expect(meds.map((m) => m.name).toList(), ['Napa', 'Sergel', 'Monas']);
    });

    test('valid medicines survive even when one row is invalid', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList('''
        [
          {"name": "Napa", "dosage": "500 mg", "confidence": 0.9},
          {"name": "", "dosage": "5 mg", "confidence": 0.8},
          {"name": "Sergel", "dosage": "20 mg", "confidence": 0.85}
        ]
      ''');
      expect(meds, isNotNull);
      // Row without a name must be dropped; valid rows must survive.
      expect(meds!.map((m) => m.name).toList(), ['Napa', 'Sergel']);
    });

    test('mixed high/low confidence in multi-medicine output', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList('''
        [
          {"name": "Napa", "dosage": "500 mg", "confidence": 0.95},
          {"name": "Monas", "dosage": "", "frequency": "", "confidence": 0.2}
        ]
      ''');
      expect(meds, isNotNull);
      expect(meds!.length, 2);
      // High-confidence row: no uncertain fields for dosage (present).
      expect(meds[0].uncertainFields, isNot(contains('dosage')));
      // Low-confidence row with empty fields: dosage and frequency flagged.
      expect(meds[1].uncertainFields, contains('dosage'));
      expect(meds[1].uncertainFields, contains('frequency'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bengali medicine names
  // ─────────────────────────────────────────────────────────────────────────
  group('Bengali medicine names', () {
    test('Bengali name passes the Unicode name validator', () {
      final meds = [
        PrescriptionMedication(name: 'নাপা'),         // "Napa" in Bengali
        PrescriptionMedication(name: 'সার্জেল'),      // "Sergel" in Bengali
        PrescriptionMedication(name: 'প্যারাসিটামল'), // "Paracetamol"
      ];
      final ok = PrescriptionOcrServiceTestAccess.validate(meds);
      // All three have length ≥ 2 and consist of Unicode letters — must pass.
      expect(ok.length, 3);
    });

    test('Bengali name parsed from JSON survives unchanged', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "নাপা", "dosage": "500 mg", "confidence": 0.9}]',
      );
      expect(meds, isNotNull);
      expect(meds!.length, 1);
      expect(meds.first.name, 'নাপা');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Missing fields — uncertainty behaviour
  // ─────────────────────────────────────────────────────────────────────────
  group('missing fields — uncertainty behaviour', () {
    test('missing dosage on low-confidence row -> dosage in uncertainFields', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Napa", "dosage": "", "confidence": 0.4}]',
      );
      expect(meds!.first.uncertainFields, contains('dosage'));
    });

    test('missing frequency on low-confidence row -> frequency uncertain', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Sergel", "frequency": "", "confidence": 0.5}]',
      );
      expect(meds!.first.uncertainFields, contains('frequency'));
    });

    test('missing duration on low-confidence row -> duration uncertain', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Monas", "duration": "", "confidence": 0.3}]',
      );
      expect(meds!.first.uncertainFields, contains('duration'));
    });

    test('missing instructions on low-confidence row -> instructions uncertain',
        () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Napa", "instructions": "", "confidence": 0.2}]',
      );
      expect(meds!.first.uncertainFields, contains('instructions'));
    });

    test('all fields empty on high-confidence row are NOT flagged uncertain',
        () {
      // High confidence (≥0.75) means the field is intentionally absent, not
      // unreadable — do not flag it.
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Napa", "dosage": "", "frequency": "", "confidence": 0.9}]',
      );
      expect(meds!.first.uncertainFields, isEmpty);
    });

    test('confidence boundary: exactly 0.75 does not flag empty fields', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Napa", "dosage": "", "confidence": 0.75}]',
      );
      // 0.75 is NOT less than 0.75, so the field must not be flagged.
      expect(meds!.first.uncertainFields, isNot(contains('dosage')));
    });

    test('confidence just below 0.75 flags empty fields', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Napa", "dosage": "", "confidence": 0.74}]',
      );
      expect(meds!.first.uncertainFields, contains('dosage'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Malformed model output
  // ─────────────────────────────────────────────────────────────────────────
  group('malformed OCR output handling', () {
    test('plain text with no JSON returns null', () {
      expect(
        PrescriptionOcrServiceTestAccess.parseList(
            'The prescription says Napa twice daily.'),
        isNull,
      );
    });

    test('truncated JSON array returns null', () {
      // Deliberately truncated — JSON decoder will throw FormatException.
      expect(
        PrescriptionOcrServiceTestAccess.parseList(
            '[{"name": "Napa", "dosage": "500'),
        isNull,
      );
    });

    test('empty JSON array returns empty list (not null)', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList('[]');
      expect(meds, isNotNull);
      expect(meds, isEmpty);
    });

    test('JSON object (not array) returns null', () {
      expect(
        PrescriptionOcrServiceTestAccess.parseList(
            '{"name": "Napa", "dosage": "500 mg"}'),
        isNull,
      );
    });

    test('array of primitives yields empty list', () {
      final meds =
          PrescriptionOcrServiceTestAccess.parseList('[1, 2, "text", true]');
      expect(meds, isNotNull);
      expect(meds, isEmpty);
    });

    test('array with null entries is handled safely', () {
      // Null entries are not Maps, so whereType<Map> drops them.
      final meds = PrescriptionOcrServiceTestAccess.parseList(
          '[null, {"name": "Napa"}, null]');
      expect(meds, isNotNull);
      expect(meds!.length, 1);
      expect(meds.first.name, 'Napa');
    });

    test('medication object with null name field is dropped', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": null, "dosage": "500 mg"}]',
      );
      // null coerced to "" then dropped by empty-name check.
      expect(meds, isNotNull);
      expect(meds, isEmpty);
    });

    test('extra unknown fields in JSON are ignored safely', () {
      final meds = PrescriptionOcrServiceTestAccess.parseList(
        '[{"name": "Napa", "dosage": "500 mg", "unknownField": "xyz", '
        '"confidence": 0.9}]',
      );
      expect(meds, isNotNull);
      expect(meds!.length, 1);
      expect(meds.first.name, 'Napa');
    });

    test('validation rejects single-character names', () {
      final ok = PrescriptionOcrServiceTestAccess.validate([
        PrescriptionMedication(name: 'A'),
        PrescriptionMedication(name: 'Napa'),
      ]);
      expect(ok.length, 1);
      expect(ok.first.name, 'Napa');
    });

    test('validation rejects names starting with punctuation', () {
      final ok = PrescriptionOcrServiceTestAccess.validate([
        PrescriptionMedication(name: '---'),
        PrescriptionMedication(name: '.Napa'),
        PrescriptionMedication(name: 'Napa'),
      ]);
      expect(ok.length, 1);
      expect(ok.first.name, 'Napa');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Test access shim — exposes private static methods for testing.
// ─────────────────────────────────────────────────────────────────────────────
class PrescriptionOcrServiceTestAccess {
  static List<PrescriptionMedication>? parseList(String text) =>
      PrescriptionOcrService.parseJsonListForTest(text);

  static List<PrescriptionMedication> validate(
    List<PrescriptionMedication> meds,
  ) =>
      PrescriptionOcrService.validateForTest(meds);
}
