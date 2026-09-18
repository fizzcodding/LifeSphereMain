import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/medicine/prescription_medication.dart';
import '../../models/medicine/reminder_model.dart';
import '../../services/prescription/prescription_ocr_service.dart';
import '../../services/prescription/prescription_reminder_mapper.dart';
import '../../services/reminder_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';
import '../../widgets/sidebar.dart';

/// Review step: every OCR-extracted medication is shown as an editable card
/// with uncertainty flags, reminder configuration, duplicate checks, and a
/// mandatory explicit confirmation before anything is saved.
///
/// Unconfirmed output never reaches the reminder system — saving happens
/// only through the Confirm action below.
class PrescriptionReviewScreen extends StatefulWidget {
  final PrescriptionScanResult result;
  final Uint8List? previewBytes;

  const PrescriptionReviewScreen({
    super.key,
    required this.result,
    this.previewBytes,
  });

  @override
  State<PrescriptionReviewScreen> createState() =>
      _PrescriptionReviewScreenState();
}

class _PrescriptionReviewScreenState extends State<PrescriptionReviewScreen> {
  late final List<_EditableMed> _meds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _meds = widget.result.medications
        .map((m) => _EditableMed(medication: m, times: _initialTimes(m)))
        .toList();
  }

  List<TimeOfDay> _initialTimes(PrescriptionMedication m) {
    final fromFreq = PrescriptionReminderMapper.timesFromFrequency(m.frequency);
    if (fromFreq.isNotEmpty) return fromFreq;
    // Frequency was unreadable/unknown — the card prompts the user to pick
    // times manually rather than the system inventing them.
    return [];
  }

  // ------------------------------------------------------------- operations

  void _removeAt(int i) {
    setState(() => _meds.removeAt(i));
  }

  void _touch() => setState(() {});

  void _addBlank() {
    setState(() {
      _meds.add(_EditableMed(
        medication: PrescriptionMedication(name: ''),
        times: const [],
      ));
    });
  }

  // -------------------------------------------------------------- validation

  bool _hasBlockingIssues() => _meds.isEmpty;

  List<String> _issuesFor(_EditableMed m) {
    final issues = <String>[];
    if (m.medication.name.trim().isEmpty) issues.add('Name is required.');
    if (m.times.isEmpty) {
      issues.add('Pick at least one reminder time.');
    }
    if (m.days.isEmpty) issues.add('Select the days to remind.');
    return issues;
  }

  bool _isReady(_EditableMed m) => _issuesFor(m).isEmpty;

  // ------------------------------------------------------------------- save

  Future<void> _confirm() async {
    // Block rows with missing essentials; everything else was user-editable.
    for (final m in _meds) {
      if (!_isReady(m)) {
        showErrorToast('Complete the highlighted fields before confirming.');
        return;
      }
    }
    if (_hasBlockingIssues()) {
      showErrorToast('Add at least one medicine to confirm.');
      return;
    }

    // Duplicate detection against existing reminders.
    final existing = await ReminderService.getReminders().first;
    final duplicates = <_EditableMed, List<ReminderWithId>>{};
    for (final m in _meds) {
      final dups = PrescriptionReminderMapper.findDuplicates(
        m.medication.name,
        existing,
      );
      if (dups.isNotEmpty) duplicates[m] = dups;
    }

    if (duplicates.isNotEmpty && mounted) {
      final proceed = await _resolveDuplicates(duplicates);
      if (!proceed) return;
    }

    await _saveAll();
  }

  Future<bool> _resolveDuplicates(
    Map<_EditableMed, List<ReminderWithId>> duplicates,
  ) async {
    final buffer = StringBuffer();
    duplicates.forEach((med, dups) {
      buffer.writeln('• ${med.medication.name.trim()} (already have '
          '${dups.length} reminder${dups.length == 1 ? '' : 's'})');
    });

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Possible Duplicates'),
        content: Text(
          'These medicines already have reminders:\n\n$buffer\n'
          'Keep both, or skip the scanned copies?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Go Back'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('Skip Duplicates'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Add Anyway'),
          ),
        ],
      ),
    );

    if (action == 'skip' || action == 'cancel') {
      if (action == 'skip' && mounted) {
        setState(() => _meds.removeWhere(duplicates.containsKey));
        showSuccessToast('Skipped duplicate medicines.');
      }
      return false;
    }
    return true;
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      var count = 0;
      for (final m in _meds) {
        final reminders = PrescriptionReminderMapper.toReminders(
          MedicationReminderDraft(
            medication: m.medication,
            times: m.times,
            days: m.days,
            slot: m.slot,
            note: m.note,
          ),
        );
        for (final r in reminders) {
          await ReminderService.addReminder(r);
          count++;
        }
      }
      if (!mounted) return;
      showSuccessToast('$count reminder${count == 1 ? '' : 's'} created '
          'from prescription.');
      // Scan screen used pushReplacement, so one pop returns to reminders.
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      showErrorToast('Could not save reminders. Check your connection and '
          'try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Prescription'),
        actions: [
          IconButton(
            tooltip: 'Reject scan',
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _rejectScan(),
          ),
        ],
      ),
      body: _meds.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              itemCount: _meds.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => _MedicationCard(
                key: ValueKey(_meds[i]),
                med: _meds[i],
                index: i,
                onChanged: _touch,
                onRemove: () => _removeAt(i),
              ),
            ),
      bottomNavigationBar: _meds.isEmpty ? null : _buildBottomBar(),
      floatingActionButton: _meds.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addBlank,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Medicine'),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: PremiumPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note_alt_outlined,
                  size: 48, color: AppTheme.muted),
              const SizedBox(height: 14),
              Text('No medicines to review',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Add one manually or go back and rescan.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => _rejectScan(),
                child: const Text('Reject Scan'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _saving ? null : _confirm,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.surface),
                      )
                    : const Text('Confirm & Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectScan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject This Scan?'),
        content: const Text(
            'Nothing has been saved. You can scan again or add medicines '
            'manually.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Discard',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context); // scan screen used pushReplacement
    }
  }
}

/// Mutable review state for one medication card.
class _EditableMed {
  final PrescriptionMedication medication;
  final List<TimeOfDay> times;
  final Set<String> days = PrescriptionReminderMapper.dayNames.toSet();
  String slot = '1';
  String note = '';

  /// True while the reminder times are still the auto-derived defaults (i.e.
  /// the user has not manually added or deleted any time chip).  When this is
  /// true, editing the Frequency text field will re-derive the suggestions.
  /// Once the user touches the time chips the flag becomes false and frequency
  /// edits no longer overwrite the user's choices.
  bool timesAreDefault;

  _EditableMed({required this.medication, required this.times})
      : timesAreDefault = times.isNotEmpty;
}

// ------------------------------------------------------------------- card

class _MedicationCard extends StatelessWidget {
  final _EditableMed med;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _MedicationCard({
    super.key,
    required this.med,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final m = med.medication;
    final issues = _issuesOf(med);
    final hasIssues = issues.isNotEmpty;

    return PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Medicine ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _ConfidenceBadge(confidence: m.confidence),
              IconButton(
                tooltip: 'Remove medicine',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
          if (hasIssues) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $issue',
                        style: const TextStyle(
                            color: AppTheme.danger, fontSize: 12.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _Field(
            label: 'Name',
            initialValue: m.name,
            uncertain: m.uncertainFields.contains('name'),
            hintText: 'Medicine name',
            onChanged: (v) => m.name = v,
          ),
          _Field(
            label: 'Dosage',
            initialValue: m.dosage,
            uncertain: m.uncertainFields.contains('dosage'),
            hintText: 'e.g. 500 mg',
            onChanged: (v) => m.dosage = v,
          ),
          _Field(
            label: 'Frequency',
            initialValue: m.frequency,
            uncertain: m.uncertainFields.contains('frequency'),
            hintText: 'e.g. twice daily',
            onChanged: (v) {
              m.frequency = v;
              // Re-derive suggested times only while the user has not yet
              // manually edited the time chips.
              if (med.timesAreDefault) {
                final derived =
                    PrescriptionReminderMapper.timesFromFrequency(v);
                med.times
                  ..clear()
                  ..addAll(derived);
              }
              onChanged();
            },
          ),
          _Field(
            label: 'Duration',
            initialValue: m.duration,
            uncertain: m.uncertainFields.contains('duration'),
            hintText: 'e.g. 7 days',
            onChanged: (v) => m.duration = v,
          ),
          _Field(
            label: 'Instructions',
            initialValue: m.instructions,
            uncertain: m.uncertainFields.contains('instructions'),
            hintText: 'e.g. after food',
            onChanged: (v) => m.instructions = v,
          ),
          _Field(
            label: 'Timing',
            initialValue: m.timing,
            uncertain: m.uncertainFields.contains('timing'),
            hintText: 'e.g. after dinner',
            onChanged: (v) => m.timing = v,
          ),
          _Field(
            label: 'Quantity',
            initialValue: m.quantity,
            uncertain: m.uncertainFields.contains('quantity'),
            hintText: 'e.g. 20 tablets',
            onChanged: (v) => m.quantity = v,
          ),
          const SizedBox(height: 6),
          _TimesEditor(med: med, onChanged: onChanged),
          const SizedBox(height: 10),
          _DaysEditor(med: med, onChanged: onChanged),
          const SizedBox(height: 10),
          _SlotEditor(med: med),
        ],
      ),
    );
  }

  List<String> _issuesOf(_EditableMed med) {
    final issues = <String>[];
    if (med.medication.name.trim().isEmpty) issues.add('Name is required.');
    if (med.times.isEmpty) issues.add('Pick at least one reminder time.');
    if (med.days.isEmpty) issues.add('Select the days to remind.');
    return issues;
  }
}

/// Shows extraction confidence; low values render as a visible warning so
/// uncertain OCR output is obvious before confirmation.
class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final low = confidence < 0.75;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (low ? AppTheme.danger : AppTheme.secondary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            low ? Icons.warning_amber_rounded : Icons.verified_rounded,
            size: 13,
            color: low ? AppTheme.danger : AppTheme.secondary,
          ),
          const SizedBox(width: 5),
          Text(
            low ? 'Verify' : 'OK',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: low ? AppTheme.danger : AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Labeled text field with an uncertainty marker for OCR-flagged fields.
/// Stateful so a card recreated by the lazy ListView shows the user's
/// current edits (via the model), not the original OCR text.
class _Field extends StatefulWidget {
  final String label;
  final String initialValue;
  final bool uncertain;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _Field({
    required this.label,
    required this.initialValue,
    required this.uncertain,
    required this.hintText,
    required this.onChanged,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted)),
              if (widget.uncertain) ...[
                const SizedBox(width: 6),
                const Icon(Icons.help_outline_rounded,
                    size: 14, color: AppTheme.danger),
                const SizedBox(width: 3),
                const Text('needs check',
                    style: TextStyle(fontSize: 11, color: AppTheme.danger)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: widget.hintText,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

/// Reminder times (existing schema: one reminder per time).
class _TimesEditor extends StatelessWidget {
  final _EditableMed med;
  final VoidCallback onChanged;

  const _TimesEditor({required this.med, required this.onChanged});

  Future<void> _add(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    if (med.times.any((t) => t.hour == picked.hour && t.minute == picked.minute)) {
      return;
    }
    med.times.add(picked);
    med.times.sort((a, b) => (a.hour * 60 + a.minute)
        .compareTo(b.hour * 60 + b.minute));
    // The user has now made a deliberate choice — stop re-deriving on
    // frequency edits.
    med.timesAreDefault = false;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Reminder Times',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted)),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await _add(context);
              },
              icon: const Icon(Icons.add_alarm_rounded, size: 16),
              label: const Text('Add', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in med.times)
              InputChip(
                label: Text(t.format(context)),
                onDeleted: () {
                  med.times.remove(t);
                  // User has manually modified the time list.
                  med.timesAreDefault = false;
                  onChanged();
                },
                backgroundColor: AppTheme.background,
                side: const BorderSide(color: AppTheme.border),
              ),
            if (med.times.isEmpty)
              const Text(
                'No time set — add at least one.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.danger),
              ),
          ],
        ),
      ],
    );
  }
}

/// Days-of-week editor, matching AddReminderDialog's chips.
class _DaysEditor extends StatelessWidget {
  final _EditableMed med;
  final VoidCallback onChanged;

  const _DaysEditor({required this.med, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repeat On',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PrescriptionReminderMapper.dayNames.map((day) {
            final sel = med.days.contains(day);
            return FilterChip(
              label: Text(day),
              selected: sel,
              selectedColor: AppTheme.secondary.withValues(alpha: 0.18),
              checkmarkColor: AppTheme.primary,
              backgroundColor: AppTheme.background,
              side: BorderSide(color: sel ? AppTheme.secondary : AppTheme.border),
              onSelected: (v) {
                v ? med.days.add(day) : med.days.remove(day);
                onChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Dispenser slot selector — always user-chosen, never inferred from OCR.
class _SlotEditor extends StatelessWidget {
  final _EditableMed med;

  const _SlotEditor({required this.med});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: med.slot,
      decoration: const InputDecoration(
        labelText: 'Dispenser Slot',
        isDense: true,
      ),
      items: ['1', '2', '3', '4', '5', '6']
          .map((s) => DropdownMenuItem(value: s, child: Text('Slot $s')))
          .toList(),
      onChanged: (v) {
        if (v != null) med.slot = v;
      },
    );
  }
}
