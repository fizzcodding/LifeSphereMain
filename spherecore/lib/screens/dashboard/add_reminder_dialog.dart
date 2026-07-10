import 'package:flutter/material.dart';
import '../../models/medicine/medicine_reminder.dart';
import '../../models/medicine/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';

class AddReminderDialog extends StatefulWidget {
  final ReminderWithId? initial;

  const AddReminderDialog({super.key, this.initial});

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _slots = ['1', '2', '3', '4', '5', '6'];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _noteCtrl;
  late String _slot;
  late Set<String> _selectedDays;
  TimeOfDay? _time;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial?.reminder;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _noteCtrl = TextEditingController(text: r?.note ?? '');
    _slot = r?.slot ?? '1';
    _selectedDays = r?.days.toSet() ?? {};
    _time = _parseTime(r?.time);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$', caseSensitive: false).firstMatch(value);
    if (m == null) return null;
    var h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (m.group(3)!.toUpperCase() == 'PM' && h < 12) h += 12;
    if (m.group(3)!.toUpperCase() == 'AM' && h == 12) h = 0;
    return TimeOfDay(hour: h, minute: min);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (picked != null) setState(() => _time = picked);
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _time == null || _selectedDays.isEmpty) {
      showErrorToast('Fill name, pick time, and select a day.');
      return;
    }

    setState(() => _loading = true);

    final data = {
      'name': name,
      'slot': _slot,
      'time': _fmt(_time!),
      'days': _days.where(_selectedDays.contains).toList(),
      if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
    };

    try {
      if (widget.initial == null) {
        await ReminderService.addReminder(MedicineReminder(
          name: name,
          slot: _slot,
          time: _fmt(_time!),
          days: _days.where(_selectedDays.contains).toList(),
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        ));
        showSuccessToast('Reminder added.');
      } else {
        await ReminderService.updateReminder(widget.initial!.id, data);
        showSuccessToast('Reminder updated.');
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      showErrorToast('Failed to save reminder.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return AlertDialog(
      title: Text(editing ? 'Edit Reminder' : 'Add Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Medicine Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'Slot'),
              items: _slots
                  .map((s) => DropdownMenuItem(value: s, child: Text('Slot $s')))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _slot = v); },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.access_time_rounded),
              label: Text(_time == null ? 'Pick Time' : _time!.format(context)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.map((day) {
                final sel = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: sel,
                  selectedColor: AppTheme.secondary.withValues(alpha: 0.18),
                  checkmarkColor: AppTheme.primary,
                  backgroundColor: AppTheme.background,
                  side: BorderSide(color: sel ? AppTheme.secondary : AppTheme.border),
                  onSelected: (v) {
                    setState(() => v ? _selectedDays.add(day) : _selectedDays.remove(day));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.surface),
                )
              : Text(editing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
