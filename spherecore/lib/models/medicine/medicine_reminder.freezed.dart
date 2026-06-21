// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'medicine_reminder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MedicineReminder {

 String get name; String get slot; String get time; List<String> get days; String? get note;
/// Create a copy of MedicineReminder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MedicineReminderCopyWith<MedicineReminder> get copyWith => _$MedicineReminderCopyWithImpl<MedicineReminder>(this as MedicineReminder, _$identity);

  /// Serializes this MedicineReminder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MedicineReminder&&(identical(other.name, name) || other.name == name)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.time, time) || other.time == time)&&const DeepCollectionEquality().equals(other.days, days)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,slot,time,const DeepCollectionEquality().hash(days),note);

@override
String toString() {
  return 'MedicineReminder(name: $name, slot: $slot, time: $time, days: $days, note: $note)';
}


}

/// @nodoc
abstract mixin class $MedicineReminderCopyWith<$Res>  {
  factory $MedicineReminderCopyWith(MedicineReminder value, $Res Function(MedicineReminder) _then) = _$MedicineReminderCopyWithImpl;
@useResult
$Res call({
 String name, String slot, String time, List<String> days, String? note
});




}
/// @nodoc
class _$MedicineReminderCopyWithImpl<$Res>
    implements $MedicineReminderCopyWith<$Res> {
  _$MedicineReminderCopyWithImpl(this._self, this._then);

  final MedicineReminder _self;
  final $Res Function(MedicineReminder) _then;

/// Create a copy of MedicineReminder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? slot = null,Object? time = null,Object? days = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slot: null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,days: null == days ? _self.days : days // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MedicineReminder].
extension MedicineReminderPatterns on MedicineReminder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MedicineReminder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MedicineReminder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MedicineReminder value)  $default,){
final _that = this;
switch (_that) {
case _MedicineReminder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MedicineReminder value)?  $default,){
final _that = this;
switch (_that) {
case _MedicineReminder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String slot,  String time,  List<String> days,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MedicineReminder() when $default != null:
return $default(_that.name,_that.slot,_that.time,_that.days,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String slot,  String time,  List<String> days,  String? note)  $default,) {final _that = this;
switch (_that) {
case _MedicineReminder():
return $default(_that.name,_that.slot,_that.time,_that.days,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String slot,  String time,  List<String> days,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _MedicineReminder() when $default != null:
return $default(_that.name,_that.slot,_that.time,_that.days,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MedicineReminder implements MedicineReminder {
  const _MedicineReminder({required this.name, required this.slot, required this.time, required final  List<String> days, this.note}): _days = days;
  factory _MedicineReminder.fromJson(Map<String, dynamic> json) => _$MedicineReminderFromJson(json);

@override final  String name;
@override final  String slot;
@override final  String time;
 final  List<String> _days;
@override List<String> get days {
  if (_days is EqualUnmodifiableListView) return _days;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_days);
}

@override final  String? note;

/// Create a copy of MedicineReminder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MedicineReminderCopyWith<_MedicineReminder> get copyWith => __$MedicineReminderCopyWithImpl<_MedicineReminder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MedicineReminderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MedicineReminder&&(identical(other.name, name) || other.name == name)&&(identical(other.slot, slot) || other.slot == slot)&&(identical(other.time, time) || other.time == time)&&const DeepCollectionEquality().equals(other._days, _days)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,slot,time,const DeepCollectionEquality().hash(_days),note);

@override
String toString() {
  return 'MedicineReminder(name: $name, slot: $slot, time: $time, days: $days, note: $note)';
}


}

/// @nodoc
abstract mixin class _$MedicineReminderCopyWith<$Res> implements $MedicineReminderCopyWith<$Res> {
  factory _$MedicineReminderCopyWith(_MedicineReminder value, $Res Function(_MedicineReminder) _then) = __$MedicineReminderCopyWithImpl;
@override @useResult
$Res call({
 String name, String slot, String time, List<String> days, String? note
});




}
/// @nodoc
class __$MedicineReminderCopyWithImpl<$Res>
    implements _$MedicineReminderCopyWith<$Res> {
  __$MedicineReminderCopyWithImpl(this._self, this._then);

  final _MedicineReminder _self;
  final $Res Function(_MedicineReminder) _then;

/// Create a copy of MedicineReminder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? slot = null,Object? time = null,Object? days = null,Object? note = freezed,}) {
  return _then(_MedicineReminder(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slot: null == slot ? _self.slot : slot // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,days: null == days ? _self._days : days // ignore: cast_nullable_to_non_nullable
as List<String>,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
