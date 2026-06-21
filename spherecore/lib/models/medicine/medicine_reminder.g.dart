// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine_reminder.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MedicineReminder _$MedicineReminderFromJson(Map<String, dynamic> json) =>
    _MedicineReminder(
      name: json['name'] as String,
      slot: json['slot'] as String,
      time: json['time'] as String,
      days: (json['days'] as List<dynamic>).map((e) => e as String).toList(),
      note: json['note'] as String?,
    );

Map<String, dynamic> _$MedicineReminderToJson(_MedicineReminder instance) =>
    <String, dynamic>{
      'name': instance.name,
      'slot': instance.slot,
      'time': instance.time,
      'days': instance.days,
      'note': instance.note,
    };
