import 'package:flutter/material.dart';

/// One medication extracted from a prescription photo.
///
/// This is *unconfirmed* OCR output. It never reaches Firebase or the
/// reminder engine directly; it must pass through the review screen where
/// the user edits and confirms it first.
class PrescriptionMedication {
  /// Brand name exactly as written on the prescription (may be Bengali).
  String name;

  /// e.g. "500 mg", "5 ml". Empty when not legible.
  String dosage;

  /// e.g. "1-0-1", "twice daily", "every 8 hours". Empty when not legible.
  String frequency;

  /// e.g. "7 days", "1 month". Empty when not legible.
  String duration;

  /// e.g. "After food". Empty when not legible.
  String instructions;

  /// Meal relationship, e.g. "before breakfast", "after dinner".
  String timing;

  /// Tablet/capsule count when written, e.g. "20".
  String quantity;

  /// Overall OCR reading confidence for this medication, 0..1.
  double confidence;

  /// Field names the extractor could not read reliably
  /// (subset of: name, dosage, frequency, duration, instructions, timing, quantity).
  final Set<String> uncertainFields;

  PrescriptionMedication({
    this.name = '',
    this.dosage = '',
    this.frequency = '',
    this.duration = '',
    this.instructions = '',
    this.timing = '',
    this.quantity = '',
    this.confidence = 0,
    Set<String>? uncertainFields,
  }) : uncertainFields = uncertainFields ?? <String>{};

  bool get isCompletelyEmpty =>
      name.isEmpty &&
      dosage.isEmpty &&
      frequency.isEmpty &&
      duration.isEmpty &&
      instructions.isEmpty &&
      timing.isEmpty &&
      quantity.isEmpty;
}

/// A confirmed-in-progress medication plus the reminder configuration the
/// user is reviewing (times, days, dispenser slot, note).
///
/// On save this is converted into the existing [MedicineReminder] format —
/// no parallel data model is created.
class MedicationReminderDraft {
  final PrescriptionMedication medication;

  /// Reminder times derived from the frequency, editable by the user.
  final List<TimeOfDay> times;

  /// Days the reminder repeats on (existing model stores 'Mon'..'Sun').
  final Set<String> days;

  /// Physical dispenser slot (1..6) — always user-selected, never inferred.
  String slot;

  /// Free-text note mapped into the existing reminder `note` field.
  String note;

  MedicationReminderDraft({
    required this.medication,
    required this.times,
    required this.days,
    this.slot = '1',
    this.note = '',
  });
}
