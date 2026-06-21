// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'virtual_pin.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VirtualPin _$VirtualPinFromJson(Map<String, dynamic> json) => _VirtualPin(
  id: json['id'] as String,
  label: json['label'] as String,
  pin: (json['pin'] as num).toInt(),
  state: json['state'] as bool,
);

Map<String, dynamic> _$VirtualPinToJson(_VirtualPin instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'pin': instance.pin,
      'state': instance.state,
    };
