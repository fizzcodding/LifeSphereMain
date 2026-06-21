import 'package:freezed_annotation/freezed_annotation.dart';

part 'virtual_pin.freezed.dart';
part 'virtual_pin.g.dart';

@freezed
abstract class VirtualPin with _$VirtualPin {
  const factory VirtualPin({
    required String id,
    required String label,
    required int pin,
    required bool state,
  }) = _VirtualPin;

  factory VirtualPin.fromJson(Map<String, dynamic> json) =>
      _$VirtualPinFromJson(json);
}
