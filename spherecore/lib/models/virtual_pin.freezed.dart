// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'virtual_pin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VirtualPin {

 String get id; String get label; int get pin; bool get state;
/// Create a copy of VirtualPin
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VirtualPinCopyWith<VirtualPin> get copyWith => _$VirtualPinCopyWithImpl<VirtualPin>(this as VirtualPin, _$identity);

  /// Serializes this VirtualPin to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VirtualPin&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,pin,state);

@override
String toString() {
  return 'VirtualPin(id: $id, label: $label, pin: $pin, state: $state)';
}


}

/// @nodoc
abstract mixin class $VirtualPinCopyWith<$Res>  {
  factory $VirtualPinCopyWith(VirtualPin value, $Res Function(VirtualPin) _then) = _$VirtualPinCopyWithImpl;
@useResult
$Res call({
 String id, String label, int pin, bool state
});




}
/// @nodoc
class _$VirtualPinCopyWithImpl<$Res>
    implements $VirtualPinCopyWith<$Res> {
  _$VirtualPinCopyWithImpl(this._self, this._then);

  final VirtualPin _self;
  final $Res Function(VirtualPin) _then;

/// Create a copy of VirtualPin
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? pin = null,Object? state = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VirtualPin].
extension VirtualPinPatterns on VirtualPin {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VirtualPin value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VirtualPin() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VirtualPin value)  $default,){
final _that = this;
switch (_that) {
case _VirtualPin():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VirtualPin value)?  $default,){
final _that = this;
switch (_that) {
case _VirtualPin() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  int pin,  bool state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VirtualPin() when $default != null:
return $default(_that.id,_that.label,_that.pin,_that.state);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  int pin,  bool state)  $default,) {final _that = this;
switch (_that) {
case _VirtualPin():
return $default(_that.id,_that.label,_that.pin,_that.state);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  int pin,  bool state)?  $default,) {final _that = this;
switch (_that) {
case _VirtualPin() when $default != null:
return $default(_that.id,_that.label,_that.pin,_that.state);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VirtualPin implements VirtualPin {
  const _VirtualPin({required this.id, required this.label, required this.pin, required this.state});
  factory _VirtualPin.fromJson(Map<String, dynamic> json) => _$VirtualPinFromJson(json);

@override final  String id;
@override final  String label;
@override final  int pin;
@override final  bool state;

/// Create a copy of VirtualPin
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VirtualPinCopyWith<_VirtualPin> get copyWith => __$VirtualPinCopyWithImpl<_VirtualPin>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VirtualPinToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VirtualPin&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&(identical(other.pin, pin) || other.pin == pin)&&(identical(other.state, state) || other.state == state));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,pin,state);

@override
String toString() {
  return 'VirtualPin(id: $id, label: $label, pin: $pin, state: $state)';
}


}

/// @nodoc
abstract mixin class _$VirtualPinCopyWith<$Res> implements $VirtualPinCopyWith<$Res> {
  factory _$VirtualPinCopyWith(_VirtualPin value, $Res Function(_VirtualPin) _then) = __$VirtualPinCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, int pin, bool state
});




}
/// @nodoc
class __$VirtualPinCopyWithImpl<$Res>
    implements _$VirtualPinCopyWith<$Res> {
  __$VirtualPinCopyWithImpl(this._self, this._then);

  final _VirtualPin _self;
  final $Res Function(_VirtualPin) _then;

/// Create a copy of VirtualPin
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? pin = null,Object? state = null,}) {
  return _then(_VirtualPin(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,pin: null == pin ? _self.pin : pin // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
