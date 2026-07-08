import 'package:flutter/material.dart';
import '../../models/medicine/medicine_reminder.dart';
import '../../models/medicine/reminder_model.dart';
import '../../services/reminder_service.dart';
import '../../themes/app_theme.dart';
import '../../utils/toast.dart';

class AddReminderDialog extends StatefulWidget {
  final ReminderWithId? initialReminder;

  const AddReminderDialog({super.key, this.initialReminder});

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _slots = ['1', '2', '3', '4', '5', '6'];

  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late String _selectedSlot;
  late Set<String> _selectedDays;
  TimeOfDay? _selectedTime;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.initialReminder?.reminder;
    _nameController = TextEditingController(text: reminder?.name ?? '');
    _noteController = TextEditingController(text: reminder?.note ?? '');
    _selectedSlot = reminder?.slot ?? '1';
    _selectedDays = reminder?.days.toSet() ?? {};
    _selectedTime = _parseTime(reminder?.time);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s?(AM|PM)$', caseSensitive: false).firstMatch(value);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveReminder() async {
    final name = _nameController.text.trim();
    final note = _noteController.text.trim();

    if (name.isEmpty || _selectedTime == null || _selectedDays.isEmpty) {
      showErrorToast('Fill name, pick time, and select a day.');
      return;
    }

    setState(() => isLoading = true);

    final time = _formatTime(_selectedTime!);
    final days = _days.where(_selectedDays.contains).toList();
    final data = {
      'name': name,
      'slot': _selectedSlot,
      'time': time,
      'days': days,
      'note': note.isEmpty ? null : note,
    };

    try {
      if (widget.initialReminder == null) {
        await ReminderService.addReminder(
          MedicineReminder(
            name: name,
            slot: _selectedSlot,
            time: time,
            days: days,
            note: note.isEmpty ? null : note,
          ),
        );
        showSuccessToast('Reminder added.');
      } else {
        await ReminderService.updateReminder(widget.initialReminder!.id, data);
        showSuccessToast('Reminder updated.');
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      showErrorToast('Failed to save reminder.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialReminder != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Reminder' : 'Add Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine Name'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedSlot,
              decoration: const InputDecoration(labelText: 'Slot'),
              items: _slots
                  .map((slot) => DropdownMenuItem(value: slot, child: Text('Slot $slot')))
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedSlot = value);
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _selectTime,
              icon: const Icon(Icons.access_time_rounded),
              label: Text(_selectedTime == null ? 'Pick Time' : _selectedTime!.format(context)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _days.map((day) {
                final selected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: selected,
                  selectedColor: AppTheme.secondary.withValues(alpha: 0.18),
                  checkmarkColor: AppTheme.primary,
                  backgroundColor: AppTheme.background,
                  side: BorderSide(
                    color: selected ? AppTheme.secondary : AppTheme.border,
                  ),
                  onSelected: (value) {
                    setState(() {
                      value ? _selectedDays.add(day) : _selectedDays.remove(day);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
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
          onPressed: isLoading ? null : _saveReminder,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.surface,
                  ),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}
