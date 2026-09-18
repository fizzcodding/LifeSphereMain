import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spherecore/models/medicine/medicine_reminder.dart';
import 'package:spherecore/models/medicine/prescription_medication.dart';
import 'package:spherecore/models/medicine/reminder_model.dart';
import 'package:spherecore/services/prescription/prescription_reminder_mapper.dart';

ReminderWithId _rem(String name) => ReminderWithId(
      id: 'r-$name',
      reminder:
          MedicineReminder(name: name, slot: '1', time: '09:00 AM', days: ['Mon']),
    );

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // timesFromFrequency — original passing cases (must stay green)
  // ─────────────────────────────────────────────────────────────────────────
  group('PrescriptionReminderMapper.timesFromFrequency — existing cases', () {
    test('explicit clock times are extracted verbatim', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('9am, 2pm, 9pm');
      expect(t.length, 3);
      expect(t[0].hour, 9);
      expect(t[1].hour, 14);
      expect(t[2].hour, 21);
    });

    test('three times daily -> 3 suggested times', () {
      final t =
          PrescriptionReminderMapper.timesFromFrequency('Three times daily');
      expect(t.length, 3);
    });

    test('twice daily -> 2 suggested times', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('Twice daily');
      expect(t.length, 2);
    });

    test('1+0+1 (plus) -> 2 suggested times', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('1+0+1');
      expect(t.length, 2);
    });

    test('every 8 hours -> 3 times', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('Every 8 hours');
      expect(t.length, 3);
    });

    test('once daily -> 1 time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('Once daily');
      expect(t.length, 1);
    });

    test('Bengali সকালে (morning with suffix) -> morning time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('সকালে');
      expect(t.length, 1);
      expect(t.first.hour, 8);
    });

    test('unknown frequency -> empty (user must pick times)', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('xyzzy');
      expect(t, isEmpty);
    });

    test('empty frequency -> empty', () {
      expect(PrescriptionReminderMapper.timesFromFrequency(''), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Fix 1+2: abbreviations, hyphen variants, new keywords
  // ─────────────────────────────────────────────────────────────────────────
  group('timesFromFrequency — abbreviations and notation (Fix 1+2)', () {
    // Hyphen variants
    test('1-0-1 (hyphen) -> 2 times (same as 1+0+1)', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('1-0-1');
      expect(t.length, 2);
    });

    test('1-1-1 (hyphen) -> 3 times', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('1-1-1');
      expect(t.length, 3);
    });

    test('0-0-1 (night only) -> 1 time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('0-0-1');
      expect(t.length, 1);
    });

    test('1-0-0 (morning only) -> 1 time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('1-0-0');
      expect(t.length, 1);
    });

    // Standard abbreviations — word-boundary matched
    test('OD -> 1 time', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('OD'), hasLength(1));
    });

    test('BD -> 2 times', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('BD'), hasLength(2));
    });

    test('BID -> 2 times', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('BID'), hasLength(2));
    });

    test('TDS -> 3 times', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('TDS'), hasLength(3));
    });

    test('QID -> 4 times', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('QID'), hasLength(4));
    });

    test('HS (bedtime) -> 1 time at night', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('HS');
      expect(t.length, 1);
      expect(t.first.hour, 21);
    });

    // As-needed: must return empty
    test('SOS -> empty (never a fixed schedule)', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('SOS'), isEmpty);
    });

    test('PRN -> empty (never a fixed schedule)', () {
      expect(PrescriptionReminderMapper.timesFromFrequency('PRN'), isEmpty);
    });

    test('as needed -> empty', () {
      expect(
          PrescriptionReminderMapper.timesFromFrequency('as needed'), isEmpty);
    });

    test('if needed -> empty', () {
      expect(
          PrescriptionReminderMapper.timesFromFrequency('if needed'), isEmpty);
    });

    // Mixed case / with context text
    test('OD in sentence context -> 1 time', () {
      expect(
          PrescriptionReminderMapper.timesFromFrequency('Take OD after food'),
          hasLength(1));
    });

    test('TDS in sentence context -> 3 times', () {
      expect(
          PrescriptionReminderMapper.timesFromFrequency('Napa 500 mg TDS'),
          hasLength(3));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Fix 1: false-positive protection for "one" substring
  // ─────────────────────────────────────────────────────────────────────────
  group('timesFromFrequency — false-positive protection (Fix 1)', () {
    test('"one tablet every 8 hours" must NOT resolve to once-daily [09:00]',
        () {
      final t = PrescriptionReminderMapper.timesFromFrequency(
          'one tablet every 8 hours');
      // Must NOT return a single 09:00 (the "once" false positive).
      // The "every 8 hours" rule should win and return 3 times.
      expect(t.length, 3);
    });

    test('"take one at night" does NOT produce once-daily default', () {
      // "one" embedded in a phrase with "night" — the night rule should win.
      final t =
          PrescriptionReminderMapper.timesFromFrequency('take one at night');
      expect(t.length, 1);
      expect(t.first.hour, 21);
    });

    test('"none" does not match OD rule', () {
      // "none" contains "one" as a substring; word-boundary must prevent match.
      final t = PrescriptionReminderMapper.timesFromFrequency('none');
      expect(t, isEmpty);
    });

    test('"procedure" does not match OD ("od" inside word)', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('procedure');
      expect(t, isEmpty);
    });

    test('"bidet" does not match BD rule', () {
      // "bidet" contains "bid" substring.
      final t = PrescriptionReminderMapper.timesFromFrequency('bidet');
      expect(t, isEmpty);
    });

    test('"SOS" in a sentence still returns empty', () {
      expect(
          PrescriptionReminderMapper.timesFromFrequency(
              'Paracetamol 500 mg SOS'),
          isEmpty);
    });

    test('"PRN" mixed with other text still returns empty', () {
      expect(
          PrescriptionReminderMapper.timesFromFrequency('1 tab PRN headache'),
          isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Bengali frequency support
  // ─────────────────────────────────────────────────────────────────────────
  group('timesFromFrequency — Bengali (Fix 2)', () {
    test('সকাল (bare, no suffix) -> morning time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('সকাল');
      expect(t.length, 1);
      expect(t.first.hour, 8);
    });

    test('সকালে (with suffix) -> morning time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('সকালে');
      expect(t.length, 1);
      expect(t.first.hour, 8);
    });

    test('দুপুর (bare) -> afternoon time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('দুপুর');
      expect(t.length, 1);
      expect(t.first.hour, 13);
    });

    test('দুপুরে (with suffix) -> afternoon time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('দুপুরে');
      expect(t.length, 1);
      expect(t.first.hour, 13);
    });

    test('রাত (bare) -> night time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('রাত');
      expect(t.length, 1);
      expect(t.first.hour, 21);
    });

    test('রাতে (with suffix) -> night time', () {
      final t = PrescriptionReminderMapper.timesFromFrequency('রাতে');
      expect(t.length, 1);
      expect(t.first.hour, 21);
    });

    test('১-০-১ as plain text is not auto-matched (no Bengali digit support — fails safe)', () {
      // Bengali digit variants are not in the matcher; fails safe to empty.
      final t = PrescriptionReminderMapper.timesFromFrequency('১-০-১');
      // Either empty or 2 — we only require it does NOT return wrong count.
      expect(t.length, isNot(3)); // must not be TDS
      expect(t.length, isNot(1)); // must not be OD
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // toReminders — multiple medicines
  // ─────────────────────────────────────────────────────────────────────────
  group('PrescriptionReminderMapper.toReminders — multiple medicines', () {
    test('three medicines produce independent reminder lists', () {
      final meds = [
        PrescriptionMedication(
            name: 'Napa', dosage: '500 mg', frequency: '1+0+1'),
        PrescriptionMedication(
            name: 'Sergel', dosage: '20 mg', frequency: 'TDS'),
        PrescriptionMedication(name: 'Monas', dosage: '10 mg', frequency: 'OD'),
      ];

      final allReminders = meds.map((m) {
        final times = PrescriptionReminderMapper.timesFromFrequency(m.frequency);
        return PrescriptionReminderMapper.toReminders(
          MedicationReminderDraft(
            medication: m,
            times: times,
            days: {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'},
            slot: '1',
          ),
        );
      }).toList();

      // Napa 1+0+1 -> 2 reminders
      expect(allReminders[0].length, 2);
      expect(allReminders[0][0].name, 'Napa');

      // Sergel TDS -> 3 reminders
      expect(allReminders[1].length, 3);
      expect(allReminders[1][0].name, 'Sergel');

      // Monas OD -> 1 reminder
      expect(allReminders[2].length, 1);
      expect(allReminders[2][0].name, 'Monas');
    });

    test('SOS medicine produces zero reminders (empty times)', () {
      final med =
          PrescriptionMedication(name: 'Panadol', frequency: 'SOS headache');
      final times =
          PrescriptionReminderMapper.timesFromFrequency(med.frequency);
      expect(times, isEmpty);
      final reminders = PrescriptionReminderMapper.toReminders(
        MedicationReminderDraft(
          medication: med,
          times: times,
          days: {'Mon'},
        ),
      );
      expect(reminders, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // toReminders — existing cases
  // ─────────────────────────────────────────────────────────────────────────
  group('PrescriptionReminderMapper.toReminders', () {
    test('expands one medication into one reminder per time', () {
      final med = PrescriptionMedication(
        name: 'Napa',
        dosage: '500 mg',
        frequency: 'three times daily',
        duration: '7 days',
        instructions: 'After food',
      );
      final draft = MedicationReminderDraft(
        medication: med,
        times: const [
          TimeOfDay(hour: 8, minute: 0),
          TimeOfDay(hour: 14, minute: 30),
        ],
        days: {'Mon', 'Tue'},
        slot: '2',
      );

      final reminders = PrescriptionReminderMapper.toReminders(draft);
      expect(reminders.length, 2);
      expect(reminders[0].name, 'Napa');
      expect(reminders[0].slot, '2');
      expect(reminders[0].time, '08:00 AM');
      expect(reminders[1].time, '02:30 PM');
      expect(reminders[0].days, ['Mon', 'Tue']);
      expect(reminders[0].note, contains('three times daily'));
      expect(reminders[0].note, contains('500 mg'));
    });

    test('empty times produce no reminders', () {
      final med = PrescriptionMedication(name: 'X');
      final draft = MedicationReminderDraft(
        medication: med,
        times: const [],
        days: {'Mon'},
      );
      expect(PrescriptionReminderMapper.toReminders(draft), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // findDuplicates — existing + edge cases
  // ─────────────────────────────────────────────────────────────────────────
  group('PrescriptionReminderMapper.findDuplicates', () {
    test('case/whitespace-insensitive matching', () {
      expect(
        PrescriptionReminderMapper.findDuplicates('napa  extra', [
          _rem('NapaExtra'),
        ]),
        isNotEmpty,
      );
      expect(
        PrescriptionReminderMapper.findDuplicates('sergel', [_rem('Sergel')]),
        isNotEmpty,
      );
      expect(
        PrescriptionReminderMapper.findDuplicates('Napa', [_rem('Sergel')]),
        isEmpty,
      );
    });

    test('empty name never matches anything', () {
      expect(
        PrescriptionReminderMapper.findDuplicates('', [_rem('Napa')]),
        isEmpty,
      );
    });

    test('no false positive when name differs by one character', () {
      // Exact normalised match only — one-char variants do not collide.
      expect(
        PrescriptionReminderMapper.findDuplicates('Naapa', [_rem('Napa')]),
        isEmpty,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // formatTime — existing + edge cases
  // ─────────────────────────────────────────────────────────────────────────
  group('PrescriptionReminderMapper.formatTime', () {
    test('formats midnight and noon correctly', () {
      expect(
        PrescriptionReminderMapper.formatTime(
            const TimeOfDay(hour: 0, minute: 5)),
        '12:05 AM',
      );
      expect(
        PrescriptionReminderMapper.formatTime(
            const TimeOfDay(hour: 12, minute: 0)),
        '12:00 PM',
      );
    });

    test('pads single-digit minutes', () {
      expect(
        PrescriptionReminderMapper.formatTime(
            const TimeOfDay(hour: 9, minute: 5)),
        '09:05 AM',
      );
    });

    test('23:59 formats as 11:59 PM', () {
      expect(
        PrescriptionReminderMapper.formatTime(
            const TimeOfDay(hour: 23, minute: 59)),
        '11:59 PM',
      );
    });
  });
}
