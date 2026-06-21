import 'package:freezed_annotation/freezed_annotation.dart';
part 'medicine_reminder.freezed.dart';
part 'medicine_reminder.g.dart';

@freezed
abstract class MedicineReminder with _$MedicineReminder {
  const factory MedicineReminder({
    required String name,
    required String slot,
    required String time,
    required List<String> days,
    String? note,
  }) = _MedicineReminder;
  factory MedicineReminder.fromJson(Map<String, dynamic> json) => _$MedicineReminderFromJson(json);
}