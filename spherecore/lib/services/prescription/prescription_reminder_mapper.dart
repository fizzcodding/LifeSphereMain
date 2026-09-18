import 'package:flutter/material.dart';

import '../../models/medicine/medicine_reminder.dart';
import '../../models/medicine/reminder_model.dart';
import '../../models/medicine/prescription_medication.dart';

/// Converts confirmed prescription data into the EXISTING reminder format
/// and checks it against the user's current reminders for duplicates.
///
/// This is the only bridge between the OCR world and the existing reminder
/// system — no parallel data model, no parallel Firebase path. The output
/// uses the same [MedicineReminder] the manual AddReminderDialog creates.
class PrescriptionReminderMapper {
  PrescriptionReminderMapper._();

  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Derives default reminder times from a frequency string.
  ///
  /// Returns suggested clock times only when the frequency unambiguously
  /// describes a regular schedule. All returned times are editable by the
  /// user on the review screen before anything is saved.
  ///
  /// SOS / PRN and similar as-needed instructions always return empty so
  /// the system never invents a fixed reminder for an on-demand medicine.
  static List<TimeOfDay> timesFromFrequency(String frequency) {
    final f = frequency.toLowerCase().trim();
    if (f.isEmpty) return const [];

    // ── 1. Explicit clock times written on the prescription ──────────────
    // e.g. "9am", "9:15 am", "9.30pm", "14:00".
    // Bare numbers alone ("3 times") are NOT matched — a time must carry
    // am/pm or a colon/dot separator to qualify.
    TimeOfDay? parseClockMatch(RegExpMatch m) {
      var h = int.parse(m.group(1)!);
      final min = int.tryParse(m.group(2) ?? '') ?? 0;
      final ap = m.group(3);
      if (min > 59 || h > 23) return null;
      if (ap == 'pm' && h < 12) h += 12;
      if (ap == 'am' && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: min);
    }

    final explicit = <TimeOfDay>{
      ...RegExp(r'(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)\b')
          .allMatches(f)
          .map(parseClockMatch)
          .whereType<TimeOfDay>(),
      // 24-hour: "14:00" — skip if am/pm immediately follows (already taken)
      ...RegExp(r'(\d{1,2})[:.](\d{2})\b(?!\s*(?:am|pm)\b)')
          .allMatches(f)
          .map(parseClockMatch)
          .whereType<TimeOfDay>(),
    }.toList()
      ..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    if (explicit.isNotEmpty) return explicit;

    // ── 2. As-needed / SOS / PRN — no fixed schedule ─────────────────────
    // These must NEVER generate a clock time; return empty so the review
    // screen requires the user to make a deliberate choice.
    if (_word(f, 'sos') || _word(f, 'prn') || _word(f, 'as needed') ||
        _word(f, 'if needed') || _word(f, 'when required')) {
      return const [];
    }

    // ── 3. Interval-based frequencies ────────────────────────────────────
    if (_hasSubstr(f, ['every 6 hour', '6 hourly', '6-hourly', '৬ ঘণ্টা'])) {
      return const [
        TimeOfDay(hour: 6, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
      ];
    }
    if (_hasSubstr(f, ['every 8 hour', '8 hourly', '8-hourly', '৮ ঘণ্টা'])) {
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
        TimeOfDay(hour: 0, minute: 0),
      ];
    }
    if (_hasSubstr(f, ['every 12 hour', '12 hourly', '12-hourly', '১২ ঘণ্টা'])) {
      return const [
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 21, minute: 0),
      ];
    }
    // Legacy "X hours" phrasing (e.g. "every 8 hours") — checked after the
    // more-specific "hourly" forms so "8 hourly" doesn't hit "8 hours" first.
    if (_hasSubstr(f, ['every 6 hours', '6 hours', '6-hour', '৬ ঘণ্টা পর'])) {
      return const [
        TimeOfDay(hour: 6, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
      ];
    }
    if (_hasSubstr(f, ['every 8 hours', '8 hours', '8-hour', '৮ ঘণ্টা পর'])) {
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 16, minute: 0),
        TimeOfDay(hour: 0, minute: 0),
      ];
    }
    if (_hasSubstr(f, ['every 12 hours', '12 hours', '১২ ঘণ্টা পর'])) {
      return const [
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 21, minute: 0),
      ];
    }

    // ── 4. Standard abbreviations & patterns (word-boundary matched) ──────

    // QID / four times — 6-hourly defaults
    if (_word(f, 'qid') ||
        _word(f, '4 times') ||
        _word(f, 'four times') ||
        _hasSubstr(f, ['৬ ঘণ্টা পর', '৪ বার'])) {
      return const [
        TimeOfDay(hour: 6, minute: 0),
        TimeOfDay(hour: 12, minute: 0),
        TimeOfDay(hour: 18, minute: 0),
        TimeOfDay(hour: 0, minute: 0),
      ];
    }

    // TDS / three times
    if (_word(f, 'tds') ||
        _word(f, 'tid') ||
        _word(f, 'thrice') ||
        _word(f, '3 times') ||
        _word(f, 'three times') ||
        _hasSubstr(f, ['1+1+1', '1-1-1', '১+১+১', '৩ বার'])) {
      return const [
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 14, minute: 0),
        TimeOfDay(hour: 20, minute: 0),
      ];
    }

    // BD / BID / twice — 1+0+1 and hyphen variants included
    if (_word(f, 'bd') ||
        _word(f, 'bid') ||
        _word(f, 'twice') ||
        _word(f, '2 times') ||
        _word(f, 'two times') ||
        _hasSubstr(f, [
          '1+0+1', '1-0-1',    // morning + night
          '১+০+১', '২ বার',
        ])) {
      return const [
        TimeOfDay(hour: 9, minute: 0),
        TimeOfDay(hour: 21, minute: 0),
      ];
    }

    // HS — hora somni (at bedtime)
    if (_word(f, 'hs')) {
      return const [TimeOfDay(hour: 21, minute: 0)];
    }

    // OD / once-daily variants.
    // Use word-boundary matching so "one tablet" or "one 8-hourly" does NOT
    // trigger the once-daily rule.
    if (_word(f, 'od') ||
        _word(f, 'once') ||
        _word(f, 'once daily') ||
        _word(f, 'daily') ||
        _hasSubstr(f, [
          '1+0+0', '1-0-0',    // morning only
          '0+0+1', '0-0-1',    // night only (treated as once-daily)
          '১ বার',
        ])) {
      return const [TimeOfDay(hour: 9, minute: 0)];
    }

    // Bengali morning / afternoon / night bare forms (with and without suffix)
    if (_hasSubstr(f, ['সকালে', 'সকাল'])) {
      return const [TimeOfDay(hour: 8, minute: 0)];
    }
    if (_hasSubstr(f, ['দুপুরে', 'দুপুর'])) {
      return const [TimeOfDay(hour: 13, minute: 0)];
    }
    if (_hasSubstr(f, ['রাতে', 'রাত'])) {
      return const [TimeOfDay(hour: 21, minute: 0)];
    }

    // English time-of-day words
    if (_word(f, 'morning')) return const [TimeOfDay(hour: 8, minute: 0)];
    if (_word(f, 'afternoon')) return const [TimeOfDay(hour: 13, minute: 0)];
    if (_hasSubstr(f, ['night', 'bedtime', 'nocte'])) {
      return const [TimeOfDay(hour: 21, minute: 0)];
    }

    // Unrecognized — return empty and require user to pick times.
    return const [];
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// True when [needle] appears as a complete word (or phrase) inside [hay].
  /// Uses `\b` word-boundaries so "od" doesn't match inside "procedure" and
  /// "once" doesn't match "ounce".  ASCII-safe: works for Latin keywords;
  /// Bengali keys must use [_hasSubstr] instead.
  static bool _word(String hay, String needle) {
    // Escape any regex special chars in the needle (e.g. the '+' in future use)
    final escaped = RegExp.escape(needle);
    return RegExp('(?<![\\w])$escaped(?![\\w])').hasMatch(hay);
  }

  /// Simple substring check for patterns that are self-delimiting (numeric
  /// patterns like "1+0+1", Bengali Unicode strings, multi-word phrases that
  /// already carry their own delimiters).
  static bool _hasSubstr(String hay, List<String> needles) =>
      needles.any(hay.contains);

  /// Builds the reminder note from non-schedule prescription fields so the
  /// information is not lost in the existing single-note schema.
  static String buildNote(PrescriptionMedication m) {
    final parts = <String>[];
    if (m.dosage.isNotEmpty) parts.add(m.dosage);
    if (m.duration.isNotEmpty) parts.add(m.duration);
    if (m.timing.isNotEmpty) parts.add(m.timing);
    if (m.instructions.isNotEmpty) parts.add(m.instructions);
    if (m.quantity.isNotEmpty) parts.add('Qty: ${m.quantity}');
    return parts.join(' • ');
  }

  /// Converts one reviewed draft into an existing-format reminder.
  static MedicineReminder toReminder(MedicationReminderDraft draft) {
    final med = draft.medication;
    return MedicineReminder(
      name: med.name.trim(),
      slot: draft.slot,
      time: formatTime(draft.times.first),
      days: dayNames.where(draft.days.contains).toList(),
      note: _withFrequency(med, draft),
    );
  }

  static String _withFrequency(PrescriptionMedication med, MedicationReminderDraft draft) {
    final note = buildNote(med);
    final freq = med.frequency.trim();
    final base = note.isEmpty ? '' : note;
    if (freq.isEmpty) return base;
    // One reminder per day carries the frequency for downstream consumers
    // (HollowCore/dispenser) without changing the existing schema.
    final prefix = '[$freq] ';
    return base.isEmpty ? prefix.trim() : '$prefix$base';
  }

  /// One draft can expand to several reminders when the user kept multiple
  /// times per day (existing model stores a single time per entry).
  static List<MedicineReminder> toReminders(MedicationReminderDraft draft) {
    if (draft.times.isEmpty) return [];
    return draft.times.map((t) {
      final r = toReminder(draft);
      return MedicineReminder(
        name: r.name,
        slot: r.slot,
        time: formatTime(t),
        days: r.days,
        note: r.note,
      );
    }).toList();
  }

  /// "9:05 AM" — exactly the format AddReminderDialog already stores.
  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$m ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  /// Finds likely duplicates of [name] among the user's existing reminders
  /// (case-insensitive name match, ignoring whitespace).
  static List<ReminderWithId> findDuplicates(
    String name,
    List<ReminderWithId> existing,
  ) {
    final key = _normalize(name);
    if (key.isEmpty) return const [];
    return existing
        .where((r) => _normalize(r.reminder.name) == key)
        .toList();
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
}
