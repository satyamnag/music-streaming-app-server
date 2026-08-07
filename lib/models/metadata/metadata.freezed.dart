// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SangeetAudioSourceContainerPreset _$SangeetAudioSourceContainerPresetFromJson(
    Map<String, dynamic> json) {
  switch (json['type']) {
    case 'lossy':
      return SangeetAudioSourceContainerPresetLossy.fromJson(json);
    case 'lossless':
      return SangeetAudioSourceContainerPresetLossless.fromJson(json);

    default:
      throw CheckedFromJsonException(
          json,
          'type',
          'SangeetAudioSourceContainerPreset',
          'Invalid union type "${json['type']}"!');
  }
}

/// @nodoc
mixin _$SangeetAudioSourceContainerPreset {
  SangeetMediaCompressionType get type => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<Object> get qualities => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)
        lossy,
    required TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)?
        lossy,
    TResult? Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)?
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)?
        lossy,
    TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)?
        lossless,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SangeetAudioSourceContainerPresetLossy value)
        lossy,
    required TResult Function(SangeetAudioSourceContainerPresetLossless value)
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SangeetAudioSourceContainerPresetLossy value)? lossy,
    TResult? Function(SangeetAudioSourceContainerPresetLossless value)?
        lossless,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SangeetAudioSourceContainerPresetLossy value)? lossy,
    TResult Function(SangeetAudioSourceContainerPresetLossless value)? lossless,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this SangeetAudioSourceContainerPreset to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetAudioSourceContainerPresetCopyWith<SangeetAudioSourceContainerPreset>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetAudioSourceContainerPresetCopyWith<$Res> {
  factory $SangeetAudioSourceContainerPresetCopyWith(
          SangeetAudioSourceContainerPreset value,
          $Res Function(SangeetAudioSourceContainerPreset) then) =
      _$SangeetAudioSourceContainerPresetCopyWithImpl<$Res,
          SangeetAudioSourceContainerPreset>;
  @useResult
  $Res call({SangeetMediaCompressionType type, String name});
}

/// @nodoc
class _$SangeetAudioSourceContainerPresetCopyWithImpl<$Res,
        $Val extends SangeetAudioSourceContainerPreset>
    implements $SangeetAudioSourceContainerPresetCopyWith<$Res> {
  _$SangeetAudioSourceContainerPresetCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? name = null,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SangeetMediaCompressionType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetAudioSourceContainerPresetLossyImplCopyWith<$Res>
    implements $SangeetAudioSourceContainerPresetCopyWith<$Res> {
  factory _$$SangeetAudioSourceContainerPresetLossyImplCopyWith(
          _$SangeetAudioSourceContainerPresetLossyImpl value,
          $Res Function(_$SangeetAudioSourceContainerPresetLossyImpl) then) =
      __$$SangeetAudioSourceContainerPresetLossyImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SangeetMediaCompressionType type,
      String name,
      List<SangeetAudioLossyContainerQuality> qualities});
}

/// @nodoc
class __$$SangeetAudioSourceContainerPresetLossyImplCopyWithImpl<$Res>
    extends _$SangeetAudioSourceContainerPresetCopyWithImpl<$Res,
        _$SangeetAudioSourceContainerPresetLossyImpl>
    implements _$$SangeetAudioSourceContainerPresetLossyImplCopyWith<$Res> {
  __$$SangeetAudioSourceContainerPresetLossyImplCopyWithImpl(
      _$SangeetAudioSourceContainerPresetLossyImpl _value,
      $Res Function(_$SangeetAudioSourceContainerPresetLossyImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? name = null,
    Object? qualities = null,
  }) {
    return _then(_$SangeetAudioSourceContainerPresetLossyImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SangeetMediaCompressionType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      qualities: null == qualities
          ? _value._qualities
          : qualities // ignore: cast_nullable_to_non_nullable
              as List<SangeetAudioLossyContainerQuality>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetAudioSourceContainerPresetLossyImpl
    extends SangeetAudioSourceContainerPresetLossy {
  _$SangeetAudioSourceContainerPresetLossyImpl(
      {required this.type,
      required this.name,
      required final List<SangeetAudioLossyContainerQuality> qualities})
      : _qualities = qualities,
        super._();

  factory _$SangeetAudioSourceContainerPresetLossyImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetAudioSourceContainerPresetLossyImplFromJson(json);

  @override
  final SangeetMediaCompressionType type;
  @override
  final String name;
  final List<SangeetAudioLossyContainerQuality> _qualities;
  @override
  List<SangeetAudioLossyContainerQuality> get qualities {
    if (_qualities is EqualUnmodifiableListView) return _qualities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_qualities);
  }

  @override
  String toString() {
    return 'SangeetAudioSourceContainerPreset.lossy(type: $type, name: $name, qualities: $qualities)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetAudioSourceContainerPresetLossyImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._qualities, _qualities));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, name, const DeepCollectionEquality().hash(_qualities));

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetAudioSourceContainerPresetLossyImplCopyWith<
          _$SangeetAudioSourceContainerPresetLossyImpl>
      get copyWith =>
          __$$SangeetAudioSourceContainerPresetLossyImplCopyWithImpl<
              _$SangeetAudioSourceContainerPresetLossyImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)
        lossy,
    required TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)
        lossless,
  }) {
    return lossy(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)?
        lossy,
    TResult? Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)?
        lossless,
  }) {
    return lossy?.call(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)?
        lossy,
    TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)?
        lossless,
    required TResult orElse(),
  }) {
    if (lossy != null) {
      return lossy(type, name, qualities);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SangeetAudioSourceContainerPresetLossy value)
        lossy,
    required TResult Function(SangeetAudioSourceContainerPresetLossless value)
        lossless,
  }) {
    return lossy(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SangeetAudioSourceContainerPresetLossy value)? lossy,
    TResult? Function(SangeetAudioSourceContainerPresetLossless value)?
        lossless,
  }) {
    return lossy?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SangeetAudioSourceContainerPresetLossy value)? lossy,
    TResult Function(SangeetAudioSourceContainerPresetLossless value)? lossless,
    required TResult orElse(),
  }) {
    if (lossy != null) {
      return lossy(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetAudioSourceContainerPresetLossyImplToJson(
      this,
    );
  }
}

abstract class SangeetAudioSourceContainerPresetLossy
    extends SangeetAudioSourceContainerPreset {
  factory SangeetAudioSourceContainerPresetLossy(
          {required final SangeetMediaCompressionType type,
          required final String name,
          required final List<SangeetAudioLossyContainerQuality> qualities}) =
      _$SangeetAudioSourceContainerPresetLossyImpl;
  SangeetAudioSourceContainerPresetLossy._() : super._();

  factory SangeetAudioSourceContainerPresetLossy.fromJson(
          Map<String, dynamic> json) =
      _$SangeetAudioSourceContainerPresetLossyImpl.fromJson;

  @override
  SangeetMediaCompressionType get type;
  @override
  String get name;
  @override
  List<SangeetAudioLossyContainerQuality> get qualities;

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetAudioSourceContainerPresetLossyImplCopyWith<
          _$SangeetAudioSourceContainerPresetLossyImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SangeetAudioSourceContainerPresetLosslessImplCopyWith<$Res>
    implements $SangeetAudioSourceContainerPresetCopyWith<$Res> {
  factory _$$SangeetAudioSourceContainerPresetLosslessImplCopyWith(
          _$SangeetAudioSourceContainerPresetLosslessImpl value,
          $Res Function(_$SangeetAudioSourceContainerPresetLosslessImpl) then) =
      __$$SangeetAudioSourceContainerPresetLosslessImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {SangeetMediaCompressionType type,
      String name,
      List<SangeetAudioLosslessContainerQuality> qualities});
}

/// @nodoc
class __$$SangeetAudioSourceContainerPresetLosslessImplCopyWithImpl<$Res>
    extends _$SangeetAudioSourceContainerPresetCopyWithImpl<$Res,
        _$SangeetAudioSourceContainerPresetLosslessImpl>
    implements _$$SangeetAudioSourceContainerPresetLosslessImplCopyWith<$Res> {
  __$$SangeetAudioSourceContainerPresetLosslessImplCopyWithImpl(
      _$SangeetAudioSourceContainerPresetLosslessImpl _value,
      $Res Function(_$SangeetAudioSourceContainerPresetLosslessImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? name = null,
    Object? qualities = null,
  }) {
    return _then(_$SangeetAudioSourceContainerPresetLosslessImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SangeetMediaCompressionType,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      qualities: null == qualities
          ? _value._qualities
          : qualities // ignore: cast_nullable_to_non_nullable
              as List<SangeetAudioLosslessContainerQuality>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetAudioSourceContainerPresetLosslessImpl
    extends SangeetAudioSourceContainerPresetLossless {
  _$SangeetAudioSourceContainerPresetLosslessImpl(
      {required this.type,
      required this.name,
      required final List<SangeetAudioLosslessContainerQuality> qualities})
      : _qualities = qualities,
        super._();

  factory _$SangeetAudioSourceContainerPresetLosslessImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetAudioSourceContainerPresetLosslessImplFromJson(json);

  @override
  final SangeetMediaCompressionType type;
  @override
  final String name;
  final List<SangeetAudioLosslessContainerQuality> _qualities;
  @override
  List<SangeetAudioLosslessContainerQuality> get qualities {
    if (_qualities is EqualUnmodifiableListView) return _qualities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_qualities);
  }

  @override
  String toString() {
    return 'SangeetAudioSourceContainerPreset.lossless(type: $type, name: $name, qualities: $qualities)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetAudioSourceContainerPresetLosslessImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality()
                .equals(other._qualities, _qualities));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, name, const DeepCollectionEquality().hash(_qualities));

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetAudioSourceContainerPresetLosslessImplCopyWith<
          _$SangeetAudioSourceContainerPresetLosslessImpl>
      get copyWith =>
          __$$SangeetAudioSourceContainerPresetLosslessImplCopyWithImpl<
                  _$SangeetAudioSourceContainerPresetLosslessImpl>(
              this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)
        lossy,
    required TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)
        lossless,
  }) {
    return lossless(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)?
        lossy,
    TResult? Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)?
        lossless,
  }) {
    return lossless?.call(type, name, qualities);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLossyContainerQuality> qualities)?
        lossy,
    TResult Function(SangeetMediaCompressionType type, String name,
            List<SangeetAudioLosslessContainerQuality> qualities)?
        lossless,
    required TResult orElse(),
  }) {
    if (lossless != null) {
      return lossless(type, name, qualities);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SangeetAudioSourceContainerPresetLossy value)
        lossy,
    required TResult Function(SangeetAudioSourceContainerPresetLossless value)
        lossless,
  }) {
    return lossless(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SangeetAudioSourceContainerPresetLossy value)? lossy,
    TResult? Function(SangeetAudioSourceContainerPresetLossless value)?
        lossless,
  }) {
    return lossless?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SangeetAudioSourceContainerPresetLossy value)? lossy,
    TResult Function(SangeetAudioSourceContainerPresetLossless value)? lossless,
    required TResult orElse(),
  }) {
    if (lossless != null) {
      return lossless(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetAudioSourceContainerPresetLosslessImplToJson(
      this,
    );
  }
}

abstract class SangeetAudioSourceContainerPresetLossless
    extends SangeetAudioSourceContainerPreset {
  factory SangeetAudioSourceContainerPresetLossless(
      {required final SangeetMediaCompressionType type,
      required final String name,
      required final List<SangeetAudioLosslessContainerQuality>
          qualities}) = _$SangeetAudioSourceContainerPresetLosslessImpl;
  SangeetAudioSourceContainerPresetLossless._() : super._();

  factory SangeetAudioSourceContainerPresetLossless.fromJson(
          Map<String, dynamic> json) =
      _$SangeetAudioSourceContainerPresetLosslessImpl.fromJson;

  @override
  SangeetMediaCompressionType get type;
  @override
  String get name;
  @override
  List<SangeetAudioLosslessContainerQuality> get qualities;

  /// Create a copy of SangeetAudioSourceContainerPreset
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetAudioSourceContainerPresetLosslessImplCopyWith<
          _$SangeetAudioSourceContainerPresetLosslessImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetAudioLossyContainerQuality _$SangeetAudioLossyContainerQualityFromJson(
    Map<String, dynamic> json) {
  return _SangeetAudioLossyContainerQuality.fromJson(json);
}

/// @nodoc
mixin _$SangeetAudioLossyContainerQuality {
  int get bitrate => throw _privateConstructorUsedError;

  /// Serializes this SangeetAudioLossyContainerQuality to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetAudioLossyContainerQualityCopyWith<SangeetAudioLossyContainerQuality>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetAudioLossyContainerQualityCopyWith<$Res> {
  factory $SangeetAudioLossyContainerQualityCopyWith(
          SangeetAudioLossyContainerQuality value,
          $Res Function(SangeetAudioLossyContainerQuality) then) =
      _$SangeetAudioLossyContainerQualityCopyWithImpl<$Res,
          SangeetAudioLossyContainerQuality>;
  @useResult
  $Res call({int bitrate});
}

/// @nodoc
class _$SangeetAudioLossyContainerQualityCopyWithImpl<$Res,
        $Val extends SangeetAudioLossyContainerQuality>
    implements $SangeetAudioLossyContainerQualityCopyWith<$Res> {
  _$SangeetAudioLossyContainerQualityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitrate = null,
  }) {
    return _then(_value.copyWith(
      bitrate: null == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetAudioLossyContainerQualityImplCopyWith<$Res>
    implements $SangeetAudioLossyContainerQualityCopyWith<$Res> {
  factory _$$SangeetAudioLossyContainerQualityImplCopyWith(
          _$SangeetAudioLossyContainerQualityImpl value,
          $Res Function(_$SangeetAudioLossyContainerQualityImpl) then) =
      __$$SangeetAudioLossyContainerQualityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int bitrate});
}

/// @nodoc
class __$$SangeetAudioLossyContainerQualityImplCopyWithImpl<$Res>
    extends _$SangeetAudioLossyContainerQualityCopyWithImpl<$Res,
        _$SangeetAudioLossyContainerQualityImpl>
    implements _$$SangeetAudioLossyContainerQualityImplCopyWith<$Res> {
  __$$SangeetAudioLossyContainerQualityImplCopyWithImpl(
      _$SangeetAudioLossyContainerQualityImpl _value,
      $Res Function(_$SangeetAudioLossyContainerQualityImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitrate = null,
  }) {
    return _then(_$SangeetAudioLossyContainerQualityImpl(
      bitrate: null == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetAudioLossyContainerQualityImpl
    extends _SangeetAudioLossyContainerQuality {
  _$SangeetAudioLossyContainerQualityImpl({required this.bitrate}) : super._();

  factory _$SangeetAudioLossyContainerQualityImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetAudioLossyContainerQualityImplFromJson(json);

  @override
  final int bitrate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetAudioLossyContainerQualityImpl &&
            (identical(other.bitrate, bitrate) || other.bitrate == bitrate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, bitrate);

  /// Create a copy of SangeetAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetAudioLossyContainerQualityImplCopyWith<
          _$SangeetAudioLossyContainerQualityImpl>
      get copyWith => __$$SangeetAudioLossyContainerQualityImplCopyWithImpl<
          _$SangeetAudioLossyContainerQualityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetAudioLossyContainerQualityImplToJson(
      this,
    );
  }
}

abstract class _SangeetAudioLossyContainerQuality
    extends SangeetAudioLossyContainerQuality {
  factory _SangeetAudioLossyContainerQuality({required final int bitrate}) =
      _$SangeetAudioLossyContainerQualityImpl;
  _SangeetAudioLossyContainerQuality._() : super._();

  factory _SangeetAudioLossyContainerQuality.fromJson(
          Map<String, dynamic> json) =
      _$SangeetAudioLossyContainerQualityImpl.fromJson;

  @override
  int get bitrate;

  /// Create a copy of SangeetAudioLossyContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetAudioLossyContainerQualityImplCopyWith<
          _$SangeetAudioLossyContainerQualityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetAudioLosslessContainerQuality
    _$SangeetAudioLosslessContainerQualityFromJson(Map<String, dynamic> json) {
  return _SangeetAudioLosslessContainerQuality.fromJson(json);
}

/// @nodoc
mixin _$SangeetAudioLosslessContainerQuality {
  int get bitDepth => throw _privateConstructorUsedError; // bit
  int get sampleRate => throw _privateConstructorUsedError;

  /// Serializes this SangeetAudioLosslessContainerQuality to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetAudioLosslessContainerQualityCopyWith<
          SangeetAudioLosslessContainerQuality>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetAudioLosslessContainerQualityCopyWith<$Res> {
  factory $SangeetAudioLosslessContainerQualityCopyWith(
          SangeetAudioLosslessContainerQuality value,
          $Res Function(SangeetAudioLosslessContainerQuality) then) =
      _$SangeetAudioLosslessContainerQualityCopyWithImpl<$Res,
          SangeetAudioLosslessContainerQuality>;
  @useResult
  $Res call({int bitDepth, int sampleRate});
}

/// @nodoc
class _$SangeetAudioLosslessContainerQualityCopyWithImpl<$Res,
        $Val extends SangeetAudioLosslessContainerQuality>
    implements $SangeetAudioLosslessContainerQualityCopyWith<$Res> {
  _$SangeetAudioLosslessContainerQualityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitDepth = null,
    Object? sampleRate = null,
  }) {
    return _then(_value.copyWith(
      bitDepth: null == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int,
      sampleRate: null == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetAudioLosslessContainerQualityImplCopyWith<$Res>
    implements $SangeetAudioLosslessContainerQualityCopyWith<$Res> {
  factory _$$SangeetAudioLosslessContainerQualityImplCopyWith(
          _$SangeetAudioLosslessContainerQualityImpl value,
          $Res Function(_$SangeetAudioLosslessContainerQualityImpl) then) =
      __$$SangeetAudioLosslessContainerQualityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int bitDepth, int sampleRate});
}

/// @nodoc
class __$$SangeetAudioLosslessContainerQualityImplCopyWithImpl<$Res>
    extends _$SangeetAudioLosslessContainerQualityCopyWithImpl<$Res,
        _$SangeetAudioLosslessContainerQualityImpl>
    implements _$$SangeetAudioLosslessContainerQualityImplCopyWith<$Res> {
  __$$SangeetAudioLosslessContainerQualityImplCopyWithImpl(
      _$SangeetAudioLosslessContainerQualityImpl _value,
      $Res Function(_$SangeetAudioLosslessContainerQualityImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bitDepth = null,
    Object? sampleRate = null,
  }) {
    return _then(_$SangeetAudioLosslessContainerQualityImpl(
      bitDepth: null == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int,
      sampleRate: null == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetAudioLosslessContainerQualityImpl
    extends _SangeetAudioLosslessContainerQuality {
  _$SangeetAudioLosslessContainerQualityImpl(
      {required this.bitDepth, required this.sampleRate})
      : super._();

  factory _$SangeetAudioLosslessContainerQualityImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetAudioLosslessContainerQualityImplFromJson(json);

  @override
  final int bitDepth;
// bit
  @override
  final int sampleRate;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetAudioLosslessContainerQualityImpl &&
            (identical(other.bitDepth, bitDepth) ||
                other.bitDepth == bitDepth) &&
            (identical(other.sampleRate, sampleRate) ||
                other.sampleRate == sampleRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, bitDepth, sampleRate);

  /// Create a copy of SangeetAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetAudioLosslessContainerQualityImplCopyWith<
          _$SangeetAudioLosslessContainerQualityImpl>
      get copyWith => __$$SangeetAudioLosslessContainerQualityImplCopyWithImpl<
          _$SangeetAudioLosslessContainerQualityImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetAudioLosslessContainerQualityImplToJson(
      this,
    );
  }
}

abstract class _SangeetAudioLosslessContainerQuality
    extends SangeetAudioLosslessContainerQuality {
  factory _SangeetAudioLosslessContainerQuality(
          {required final int bitDepth, required final int sampleRate}) =
      _$SangeetAudioLosslessContainerQualityImpl;
  _SangeetAudioLosslessContainerQuality._() : super._();

  factory _SangeetAudioLosslessContainerQuality.fromJson(
          Map<String, dynamic> json) =
      _$SangeetAudioLosslessContainerQualityImpl.fromJson;

  @override
  int get bitDepth; // bit
  @override
  int get sampleRate;

  /// Create a copy of SangeetAudioLosslessContainerQuality
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetAudioLosslessContainerQualityImplCopyWith<
          _$SangeetAudioLosslessContainerQualityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetAudioSourceMatchObject _$SangeetAudioSourceMatchObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetAudioSourceMatchObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetAudioSourceMatchObject {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  List<String> get artists => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  String? get thumbnail => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;

  /// Serializes this SangeetAudioSourceMatchObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetAudioSourceMatchObjectCopyWith<SangeetAudioSourceMatchObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetAudioSourceMatchObjectCopyWith<$Res> {
  factory $SangeetAudioSourceMatchObjectCopyWith(
          SangeetAudioSourceMatchObject value,
          $Res Function(SangeetAudioSourceMatchObject) then) =
      _$SangeetAudioSourceMatchObjectCopyWithImpl<$Res,
          SangeetAudioSourceMatchObject>;
  @useResult
  $Res call(
      {String id,
      String title,
      List<String> artists,
      Duration duration,
      String? thumbnail,
      String externalUri});
}

/// @nodoc
class _$SangeetAudioSourceMatchObjectCopyWithImpl<$Res,
        $Val extends SangeetAudioSourceMatchObject>
    implements $SangeetAudioSourceMatchObjectCopyWith<$Res> {
  _$SangeetAudioSourceMatchObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artists = null,
    Object? duration = null,
    Object? thumbnail = freezed,
    Object? externalUri = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<String>,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnail: freezed == thumbnail
          ? _value.thumbnail
          : thumbnail // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetAudioSourceMatchObjectImplCopyWith<$Res>
    implements $SangeetAudioSourceMatchObjectCopyWith<$Res> {
  factory _$$SangeetAudioSourceMatchObjectImplCopyWith(
          _$SangeetAudioSourceMatchObjectImpl value,
          $Res Function(_$SangeetAudioSourceMatchObjectImpl) then) =
      __$$SangeetAudioSourceMatchObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      List<String> artists,
      Duration duration,
      String? thumbnail,
      String externalUri});
}

/// @nodoc
class __$$SangeetAudioSourceMatchObjectImplCopyWithImpl<$Res>
    extends _$SangeetAudioSourceMatchObjectCopyWithImpl<$Res,
        _$SangeetAudioSourceMatchObjectImpl>
    implements _$$SangeetAudioSourceMatchObjectImplCopyWith<$Res> {
  __$$SangeetAudioSourceMatchObjectImplCopyWithImpl(
      _$SangeetAudioSourceMatchObjectImpl _value,
      $Res Function(_$SangeetAudioSourceMatchObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? artists = null,
    Object? duration = null,
    Object? thumbnail = freezed,
    Object? externalUri = null,
  }) {
    return _then(_$SangeetAudioSourceMatchObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<String>,
      duration: null == duration
          ? _value.duration
          : duration // ignore: cast_nullable_to_non_nullable
              as Duration,
      thumbnail: freezed == thumbnail
          ? _value.thumbnail
          : thumbnail // ignore: cast_nullable_to_non_nullable
              as String?,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetAudioSourceMatchObjectImpl
    implements _SangeetAudioSourceMatchObject {
  _$SangeetAudioSourceMatchObjectImpl(
      {required this.id,
      required this.title,
      required final List<String> artists,
      required this.duration,
      this.thumbnail,
      required this.externalUri})
      : _artists = artists;

  factory _$SangeetAudioSourceMatchObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetAudioSourceMatchObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String title;
  final List<String> _artists;
  @override
  List<String> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  @override
  final Duration duration;
  @override
  final String? thumbnail;
  @override
  final String externalUri;

  @override
  String toString() {
    return 'SangeetAudioSourceMatchObject(id: $id, title: $title, artists: $artists, duration: $duration, thumbnail: $thumbnail, externalUri: $externalUri)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetAudioSourceMatchObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            (identical(other.duration, duration) ||
                other.duration == duration) &&
            (identical(other.thumbnail, thumbnail) ||
                other.thumbnail == thumbnail) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      const DeepCollectionEquality().hash(_artists),
      duration,
      thumbnail,
      externalUri);

  /// Create a copy of SangeetAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetAudioSourceMatchObjectImplCopyWith<
          _$SangeetAudioSourceMatchObjectImpl>
      get copyWith => __$$SangeetAudioSourceMatchObjectImplCopyWithImpl<
          _$SangeetAudioSourceMatchObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetAudioSourceMatchObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetAudioSourceMatchObject
    implements SangeetAudioSourceMatchObject {
  factory _SangeetAudioSourceMatchObject(
      {required final String id,
      required final String title,
      required final List<String> artists,
      required final Duration duration,
      final String? thumbnail,
      required final String externalUri}) = _$SangeetAudioSourceMatchObjectImpl;

  factory _SangeetAudioSourceMatchObject.fromJson(Map<String, dynamic> json) =
      _$SangeetAudioSourceMatchObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  List<String> get artists;
  @override
  Duration get duration;
  @override
  String? get thumbnail;
  @override
  String get externalUri;

  /// Create a copy of SangeetAudioSourceMatchObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetAudioSourceMatchObjectImplCopyWith<
          _$SangeetAudioSourceMatchObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetAudioSourceStreamObject _$SangeetAudioSourceStreamObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetAudioSourceStreamObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetAudioSourceStreamObject {
  String get url => throw _privateConstructorUsedError;
  String get container => throw _privateConstructorUsedError;
  SangeetMediaCompressionType get type => throw _privateConstructorUsedError;
  String? get codec => throw _privateConstructorUsedError;
  double? get bitrate => throw _privateConstructorUsedError;
  int? get bitDepth => throw _privateConstructorUsedError;
  double? get sampleRate => throw _privateConstructorUsedError;

  /// Serializes this SangeetAudioSourceStreamObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetAudioSourceStreamObjectCopyWith<SangeetAudioSourceStreamObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetAudioSourceStreamObjectCopyWith<$Res> {
  factory $SangeetAudioSourceStreamObjectCopyWith(
          SangeetAudioSourceStreamObject value,
          $Res Function(SangeetAudioSourceStreamObject) then) =
      _$SangeetAudioSourceStreamObjectCopyWithImpl<$Res,
          SangeetAudioSourceStreamObject>;
  @useResult
  $Res call(
      {String url,
      String container,
      SangeetMediaCompressionType type,
      String? codec,
      double? bitrate,
      int? bitDepth,
      double? sampleRate});
}

/// @nodoc
class _$SangeetAudioSourceStreamObjectCopyWithImpl<$Res,
        $Val extends SangeetAudioSourceStreamObject>
    implements $SangeetAudioSourceStreamObjectCopyWith<$Res> {
  _$SangeetAudioSourceStreamObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? container = null,
    Object? type = null,
    Object? codec = freezed,
    Object? bitrate = freezed,
    Object? bitDepth = freezed,
    Object? sampleRate = freezed,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      container: null == container
          ? _value.container
          : container // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SangeetMediaCompressionType,
      codec: freezed == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String?,
      bitrate: freezed == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as double?,
      bitDepth: freezed == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int?,
      sampleRate: freezed == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetAudioSourceStreamObjectImplCopyWith<$Res>
    implements $SangeetAudioSourceStreamObjectCopyWith<$Res> {
  factory _$$SangeetAudioSourceStreamObjectImplCopyWith(
          _$SangeetAudioSourceStreamObjectImpl value,
          $Res Function(_$SangeetAudioSourceStreamObjectImpl) then) =
      __$$SangeetAudioSourceStreamObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String url,
      String container,
      SangeetMediaCompressionType type,
      String? codec,
      double? bitrate,
      int? bitDepth,
      double? sampleRate});
}

/// @nodoc
class __$$SangeetAudioSourceStreamObjectImplCopyWithImpl<$Res>
    extends _$SangeetAudioSourceStreamObjectCopyWithImpl<$Res,
        _$SangeetAudioSourceStreamObjectImpl>
    implements _$$SangeetAudioSourceStreamObjectImplCopyWith<$Res> {
  __$$SangeetAudioSourceStreamObjectImplCopyWithImpl(
      _$SangeetAudioSourceStreamObjectImpl _value,
      $Res Function(_$SangeetAudioSourceStreamObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? container = null,
    Object? type = null,
    Object? codec = freezed,
    Object? bitrate = freezed,
    Object? bitDepth = freezed,
    Object? sampleRate = freezed,
  }) {
    return _then(_$SangeetAudioSourceStreamObjectImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      container: null == container
          ? _value.container
          : container // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as SangeetMediaCompressionType,
      codec: freezed == codec
          ? _value.codec
          : codec // ignore: cast_nullable_to_non_nullable
              as String?,
      bitrate: freezed == bitrate
          ? _value.bitrate
          : bitrate // ignore: cast_nullable_to_non_nullable
              as double?,
      bitDepth: freezed == bitDepth
          ? _value.bitDepth
          : bitDepth // ignore: cast_nullable_to_non_nullable
              as int?,
      sampleRate: freezed == sampleRate
          ? _value.sampleRate
          : sampleRate // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetAudioSourceStreamObjectImpl
    implements _SangeetAudioSourceStreamObject {
  _$SangeetAudioSourceStreamObjectImpl(
      {required this.url,
      required this.container,
      required this.type,
      this.codec,
      this.bitrate,
      this.bitDepth,
      this.sampleRate});

  factory _$SangeetAudioSourceStreamObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetAudioSourceStreamObjectImplFromJson(json);

  @override
  final String url;
  @override
  final String container;
  @override
  final SangeetMediaCompressionType type;
  @override
  final String? codec;
  @override
  final double? bitrate;
  @override
  final int? bitDepth;
  @override
  final double? sampleRate;

  @override
  String toString() {
    return 'SangeetAudioSourceStreamObject(url: $url, container: $container, type: $type, codec: $codec, bitrate: $bitrate, bitDepth: $bitDepth, sampleRate: $sampleRate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetAudioSourceStreamObjectImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.container, container) ||
                other.container == container) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.codec, codec) || other.codec == codec) &&
            (identical(other.bitrate, bitrate) || other.bitrate == bitrate) &&
            (identical(other.bitDepth, bitDepth) ||
                other.bitDepth == bitDepth) &&
            (identical(other.sampleRate, sampleRate) ||
                other.sampleRate == sampleRate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, url, container, type, codec, bitrate, bitDepth, sampleRate);

  /// Create a copy of SangeetAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetAudioSourceStreamObjectImplCopyWith<
          _$SangeetAudioSourceStreamObjectImpl>
      get copyWith => __$$SangeetAudioSourceStreamObjectImplCopyWithImpl<
          _$SangeetAudioSourceStreamObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetAudioSourceStreamObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetAudioSourceStreamObject
    implements SangeetAudioSourceStreamObject {
  factory _SangeetAudioSourceStreamObject(
      {required final String url,
      required final String container,
      required final SangeetMediaCompressionType type,
      final String? codec,
      final double? bitrate,
      final int? bitDepth,
      final double? sampleRate}) = _$SangeetAudioSourceStreamObjectImpl;

  factory _SangeetAudioSourceStreamObject.fromJson(Map<String, dynamic> json) =
      _$SangeetAudioSourceStreamObjectImpl.fromJson;

  @override
  String get url;
  @override
  String get container;
  @override
  SangeetMediaCompressionType get type;
  @override
  String? get codec;
  @override
  double? get bitrate;
  @override
  int? get bitDepth;
  @override
  double? get sampleRate;

  /// Create a copy of SangeetAudioSourceStreamObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetAudioSourceStreamObjectImplCopyWith<
          _$SangeetAudioSourceStreamObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetFullAlbumObject _$SangeetFullAlbumObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetFullAlbumObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetFullAlbumObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<SangeetSimpleArtistObject> get artists =>
      throw _privateConstructorUsedError;
  List<SangeetImageObject> get images => throw _privateConstructorUsedError;
  String get releaseDate => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  int get totalTracks => throw _privateConstructorUsedError;
  SangeetAlbumType get albumType => throw _privateConstructorUsedError;
  String? get recordLabel => throw _privateConstructorUsedError;
  List<String>? get genres => throw _privateConstructorUsedError;

  /// Serializes this SangeetFullAlbumObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetFullAlbumObjectCopyWith<SangeetFullAlbumObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetFullAlbumObjectCopyWith<$Res> {
  factory $SangeetFullAlbumObjectCopyWith(SangeetFullAlbumObject value,
          $Res Function(SangeetFullAlbumObject) then) =
      _$SangeetFullAlbumObjectCopyWithImpl<$Res, SangeetFullAlbumObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<SangeetSimpleArtistObject> artists,
      List<SangeetImageObject> images,
      String releaseDate,
      String externalUri,
      int totalTracks,
      SangeetAlbumType albumType,
      String? recordLabel,
      List<String>? genres});
}

/// @nodoc
class _$SangeetFullAlbumObjectCopyWithImpl<$Res,
        $Val extends SangeetFullAlbumObject>
    implements $SangeetFullAlbumObjectCopyWith<$Res> {
  _$SangeetFullAlbumObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artists = null,
    Object? images = null,
    Object? releaseDate = null,
    Object? externalUri = null,
    Object? totalTracks = null,
    Object? albumType = null,
    Object? recordLabel = freezed,
    Object? genres = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      releaseDate: null == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      totalTracks: null == totalTracks
          ? _value.totalTracks
          : totalTracks // ignore: cast_nullable_to_non_nullable
              as int,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SangeetAlbumType,
      recordLabel: freezed == recordLabel
          ? _value.recordLabel
          : recordLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      genres: freezed == genres
          ? _value.genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetFullAlbumObjectImplCopyWith<$Res>
    implements $SangeetFullAlbumObjectCopyWith<$Res> {
  factory _$$SangeetFullAlbumObjectImplCopyWith(
          _$SangeetFullAlbumObjectImpl value,
          $Res Function(_$SangeetFullAlbumObjectImpl) then) =
      __$$SangeetFullAlbumObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<SangeetSimpleArtistObject> artists,
      List<SangeetImageObject> images,
      String releaseDate,
      String externalUri,
      int totalTracks,
      SangeetAlbumType albumType,
      String? recordLabel,
      List<String>? genres});
}

/// @nodoc
class __$$SangeetFullAlbumObjectImplCopyWithImpl<$Res>
    extends _$SangeetFullAlbumObjectCopyWithImpl<$Res,
        _$SangeetFullAlbumObjectImpl>
    implements _$$SangeetFullAlbumObjectImplCopyWith<$Res> {
  __$$SangeetFullAlbumObjectImplCopyWithImpl(
      _$SangeetFullAlbumObjectImpl _value,
      $Res Function(_$SangeetFullAlbumObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? artists = null,
    Object? images = null,
    Object? releaseDate = null,
    Object? externalUri = null,
    Object? totalTracks = null,
    Object? albumType = null,
    Object? recordLabel = freezed,
    Object? genres = freezed,
  }) {
    return _then(_$SangeetFullAlbumObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      releaseDate: null == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      totalTracks: null == totalTracks
          ? _value.totalTracks
          : totalTracks // ignore: cast_nullable_to_non_nullable
              as int,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SangeetAlbumType,
      recordLabel: freezed == recordLabel
          ? _value.recordLabel
          : recordLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      genres: freezed == genres
          ? _value._genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetFullAlbumObjectImpl implements _SangeetFullAlbumObject {
  _$SangeetFullAlbumObjectImpl(
      {required this.id,
      required this.name,
      required final List<SangeetSimpleArtistObject> artists,
      final List<SangeetImageObject> images = const [],
      required this.releaseDate,
      required this.externalUri,
      required this.totalTracks,
      required this.albumType,
      this.recordLabel,
      final List<String>? genres})
      : _artists = artists,
        _images = images,
        _genres = genres;

  factory _$SangeetFullAlbumObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetFullAlbumObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<SangeetSimpleArtistObject> _artists;
  @override
  List<SangeetSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  final List<SangeetImageObject> _images;
  @override
  @JsonKey()
  List<SangeetImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final String releaseDate;
  @override
  final String externalUri;
  @override
  final int totalTracks;
  @override
  final SangeetAlbumType albumType;
  @override
  final String? recordLabel;
  final List<String>? _genres;
  @override
  List<String>? get genres {
    final value = _genres;
    if (value == null) return null;
    if (_genres is EqualUnmodifiableListView) return _genres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'SangeetFullAlbumObject(id: $id, name: $name, artists: $artists, images: $images, releaseDate: $releaseDate, externalUri: $externalUri, totalTracks: $totalTracks, albumType: $albumType, recordLabel: $recordLabel, genres: $genres)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetFullAlbumObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.releaseDate, releaseDate) ||
                other.releaseDate == releaseDate) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.totalTracks, totalTracks) ||
                other.totalTracks == totalTracks) &&
            (identical(other.albumType, albumType) ||
                other.albumType == albumType) &&
            (identical(other.recordLabel, recordLabel) ||
                other.recordLabel == recordLabel) &&
            const DeepCollectionEquality().equals(other._genres, _genres));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      const DeepCollectionEquality().hash(_artists),
      const DeepCollectionEquality().hash(_images),
      releaseDate,
      externalUri,
      totalTracks,
      albumType,
      recordLabel,
      const DeepCollectionEquality().hash(_genres));

  /// Create a copy of SangeetFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetFullAlbumObjectImplCopyWith<_$SangeetFullAlbumObjectImpl>
      get copyWith => __$$SangeetFullAlbumObjectImplCopyWithImpl<
          _$SangeetFullAlbumObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetFullAlbumObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetFullAlbumObject implements SangeetFullAlbumObject {
  factory _SangeetFullAlbumObject(
      {required final String id,
      required final String name,
      required final List<SangeetSimpleArtistObject> artists,
      final List<SangeetImageObject> images,
      required final String releaseDate,
      required final String externalUri,
      required final int totalTracks,
      required final SangeetAlbumType albumType,
      final String? recordLabel,
      final List<String>? genres}) = _$SangeetFullAlbumObjectImpl;

  factory _SangeetFullAlbumObject.fromJson(Map<String, dynamic> json) =
      _$SangeetFullAlbumObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<SangeetSimpleArtistObject> get artists;
  @override
  List<SangeetImageObject> get images;
  @override
  String get releaseDate;
  @override
  String get externalUri;
  @override
  int get totalTracks;
  @override
  SangeetAlbumType get albumType;
  @override
  String? get recordLabel;
  @override
  List<String>? get genres;

  /// Create a copy of SangeetFullAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetFullAlbumObjectImplCopyWith<_$SangeetFullAlbumObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetSimpleAlbumObject _$SangeetSimpleAlbumObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetSimpleAlbumObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetSimpleAlbumObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SangeetSimpleArtistObject> get artists =>
      throw _privateConstructorUsedError;
  List<SangeetImageObject> get images => throw _privateConstructorUsedError;
  SangeetAlbumType get albumType => throw _privateConstructorUsedError;
  String? get releaseDate => throw _privateConstructorUsedError;

  /// Serializes this SangeetSimpleAlbumObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetSimpleAlbumObjectCopyWith<SangeetSimpleAlbumObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetSimpleAlbumObjectCopyWith<$Res> {
  factory $SangeetSimpleAlbumObjectCopyWith(SangeetSimpleAlbumObject value,
          $Res Function(SangeetSimpleAlbumObject) then) =
      _$SangeetSimpleAlbumObjectCopyWithImpl<$Res, SangeetSimpleAlbumObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetSimpleArtistObject> artists,
      List<SangeetImageObject> images,
      SangeetAlbumType albumType,
      String? releaseDate});
}

/// @nodoc
class _$SangeetSimpleAlbumObjectCopyWithImpl<$Res,
        $Val extends SangeetSimpleAlbumObject>
    implements $SangeetSimpleAlbumObjectCopyWith<$Res> {
  _$SangeetSimpleAlbumObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? images = null,
    Object? albumType = null,
    Object? releaseDate = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SangeetAlbumType,
      releaseDate: freezed == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetSimpleAlbumObjectImplCopyWith<$Res>
    implements $SangeetSimpleAlbumObjectCopyWith<$Res> {
  factory _$$SangeetSimpleAlbumObjectImplCopyWith(
          _$SangeetSimpleAlbumObjectImpl value,
          $Res Function(_$SangeetSimpleAlbumObjectImpl) then) =
      __$$SangeetSimpleAlbumObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetSimpleArtistObject> artists,
      List<SangeetImageObject> images,
      SangeetAlbumType albumType,
      String? releaseDate});
}

/// @nodoc
class __$$SangeetSimpleAlbumObjectImplCopyWithImpl<$Res>
    extends _$SangeetSimpleAlbumObjectCopyWithImpl<$Res,
        _$SangeetSimpleAlbumObjectImpl>
    implements _$$SangeetSimpleAlbumObjectImplCopyWith<$Res> {
  __$$SangeetSimpleAlbumObjectImplCopyWithImpl(
      _$SangeetSimpleAlbumObjectImpl _value,
      $Res Function(_$SangeetSimpleAlbumObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? images = null,
    Object? albumType = null,
    Object? releaseDate = freezed,
  }) {
    return _then(_$SangeetSimpleAlbumObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      albumType: null == albumType
          ? _value.albumType
          : albumType // ignore: cast_nullable_to_non_nullable
              as SangeetAlbumType,
      releaseDate: freezed == releaseDate
          ? _value.releaseDate
          : releaseDate // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetSimpleAlbumObjectImpl implements _SangeetSimpleAlbumObject {
  _$SangeetSimpleAlbumObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      required final List<SangeetSimpleArtistObject> artists,
      final List<SangeetImageObject> images = const [],
      required this.albumType,
      this.releaseDate})
      : _artists = artists,
        _images = images;

  factory _$SangeetSimpleAlbumObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetSimpleAlbumObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SangeetSimpleArtistObject> _artists;
  @override
  List<SangeetSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  final List<SangeetImageObject> _images;
  @override
  @JsonKey()
  List<SangeetImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final SangeetAlbumType albumType;
  @override
  final String? releaseDate;

  @override
  String toString() {
    return 'SangeetSimpleAlbumObject(id: $id, name: $name, externalUri: $externalUri, artists: $artists, images: $images, albumType: $albumType, releaseDate: $releaseDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetSimpleAlbumObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.albumType, albumType) ||
                other.albumType == albumType) &&
            (identical(other.releaseDate, releaseDate) ||
                other.releaseDate == releaseDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      externalUri,
      const DeepCollectionEquality().hash(_artists),
      const DeepCollectionEquality().hash(_images),
      albumType,
      releaseDate);

  /// Create a copy of SangeetSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetSimpleAlbumObjectImplCopyWith<_$SangeetSimpleAlbumObjectImpl>
      get copyWith => __$$SangeetSimpleAlbumObjectImplCopyWithImpl<
          _$SangeetSimpleAlbumObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetSimpleAlbumObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetSimpleAlbumObject implements SangeetSimpleAlbumObject {
  factory _SangeetSimpleAlbumObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      required final List<SangeetSimpleArtistObject> artists,
      final List<SangeetImageObject> images,
      required final SangeetAlbumType albumType,
      final String? releaseDate}) = _$SangeetSimpleAlbumObjectImpl;

  factory _SangeetSimpleAlbumObject.fromJson(Map<String, dynamic> json) =
      _$SangeetSimpleAlbumObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SangeetSimpleArtistObject> get artists;
  @override
  List<SangeetImageObject> get images;
  @override
  SangeetAlbumType get albumType;
  @override
  String? get releaseDate;

  /// Create a copy of SangeetSimpleAlbumObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetSimpleAlbumObjectImplCopyWith<_$SangeetSimpleAlbumObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetFullArtistObject _$SangeetFullArtistObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetFullArtistObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetFullArtistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SangeetImageObject> get images => throw _privateConstructorUsedError;
  List<String>? get genres => throw _privateConstructorUsedError;
  int? get followers => throw _privateConstructorUsedError;
  int? get songCount => throw _privateConstructorUsedError;

  /// Serializes this SangeetFullArtistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetFullArtistObjectCopyWith<SangeetFullArtistObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetFullArtistObjectCopyWith<$Res> {
  factory $SangeetFullArtistObjectCopyWith(SangeetFullArtistObject value,
          $Res Function(SangeetFullArtistObject) then) =
      _$SangeetFullArtistObjectCopyWithImpl<$Res, SangeetFullArtistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetImageObject> images,
      List<String>? genres,
      int? followers,
      int? songCount});
}

/// @nodoc
class _$SangeetFullArtistObjectCopyWithImpl<$Res,
        $Val extends SangeetFullArtistObject>
    implements $SangeetFullArtistObjectCopyWith<$Res> {
  _$SangeetFullArtistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = null,
    Object? genres = freezed,
    Object? followers = freezed,
    Object? songCount = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      genres: freezed == genres
          ? _value.genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      followers: freezed == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int?,
      songCount: freezed == songCount
          ? _value.songCount
          : songCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetFullArtistObjectImplCopyWith<$Res>
    implements $SangeetFullArtistObjectCopyWith<$Res> {
  factory _$$SangeetFullArtistObjectImplCopyWith(
          _$SangeetFullArtistObjectImpl value,
          $Res Function(_$SangeetFullArtistObjectImpl) then) =
      __$$SangeetFullArtistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetImageObject> images,
      List<String>? genres,
      int? followers,
      int? songCount});
}

/// @nodoc
class __$$SangeetFullArtistObjectImplCopyWithImpl<$Res>
    extends _$SangeetFullArtistObjectCopyWithImpl<$Res,
        _$SangeetFullArtistObjectImpl>
    implements _$$SangeetFullArtistObjectImplCopyWith<$Res> {
  __$$SangeetFullArtistObjectImplCopyWithImpl(
      _$SangeetFullArtistObjectImpl _value,
      $Res Function(_$SangeetFullArtistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = null,
    Object? genres = freezed,
    Object? followers = freezed,
    Object? songCount = freezed,
  }) {
    return _then(_$SangeetFullArtistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      genres: freezed == genres
          ? _value._genres
          : genres // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      followers: freezed == followers
          ? _value.followers
          : followers // ignore: cast_nullable_to_non_nullable
              as int?,
      songCount: freezed == songCount
          ? _value.songCount
          : songCount // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetFullArtistObjectImpl implements _SangeetFullArtistObject {
  _$SangeetFullArtistObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SangeetImageObject> images = const [],
      final List<String>? genres,
      this.followers,
      this.songCount})
      : _images = images,
        _genres = genres;

  factory _$SangeetFullArtistObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetFullArtistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SangeetImageObject> _images;
  @override
  @JsonKey()
  List<SangeetImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  final List<String>? _genres;
  @override
  List<String>? get genres {
    final value = _genres;
    if (value == null) return null;
    if (_genres is EqualUnmodifiableListView) return _genres;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final int? followers;
  @override
  final int? songCount;

  @override
  String toString() {
    return 'SangeetFullArtistObject(id: $id, name: $name, externalUri: $externalUri, images: $images, genres: $genres, followers: $followers, songCount: $songCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetFullArtistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            const DeepCollectionEquality().equals(other._genres, _genres) &&
            (identical(other.followers, followers) ||
                other.followers == followers) &&
            (identical(other.songCount, songCount) ||
                other.songCount == songCount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      externalUri,
      const DeepCollectionEquality().hash(_images),
      const DeepCollectionEquality().hash(_genres),
      followers,
      songCount);

  /// Create a copy of SangeetFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetFullArtistObjectImplCopyWith<_$SangeetFullArtistObjectImpl>
      get copyWith => __$$SangeetFullArtistObjectImplCopyWithImpl<
          _$SangeetFullArtistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetFullArtistObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetFullArtistObject implements SangeetFullArtistObject {
  factory _SangeetFullArtistObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      final List<SangeetImageObject> images,
      final List<String>? genres,
      final int? followers,
      final int? songCount}) = _$SangeetFullArtistObjectImpl;

  factory _SangeetFullArtistObject.fromJson(Map<String, dynamic> json) =
      _$SangeetFullArtistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SangeetImageObject> get images;
  @override
  List<String>? get genres;
  @override
  int? get followers;
  @override
  int? get songCount;

  /// Create a copy of SangeetFullArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetFullArtistObjectImplCopyWith<_$SangeetFullArtistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetSimpleArtistObject _$SangeetSimpleArtistObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetSimpleArtistObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetSimpleArtistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SangeetImageObject>? get images => throw _privateConstructorUsedError;

  /// Serializes this SangeetSimpleArtistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetSimpleArtistObjectCopyWith<SangeetSimpleArtistObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetSimpleArtistObjectCopyWith<$Res> {
  factory $SangeetSimpleArtistObjectCopyWith(SangeetSimpleArtistObject value,
          $Res Function(SangeetSimpleArtistObject) then) =
      _$SangeetSimpleArtistObjectCopyWithImpl<$Res, SangeetSimpleArtistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetImageObject>? images});
}

/// @nodoc
class _$SangeetSimpleArtistObjectCopyWithImpl<$Res,
        $Val extends SangeetSimpleArtistObject>
    implements $SangeetSimpleArtistObjectCopyWith<$Res> {
  _$SangeetSimpleArtistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: freezed == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetSimpleArtistObjectImplCopyWith<$Res>
    implements $SangeetSimpleArtistObjectCopyWith<$Res> {
  factory _$$SangeetSimpleArtistObjectImplCopyWith(
          _$SangeetSimpleArtistObjectImpl value,
          $Res Function(_$SangeetSimpleArtistObjectImpl) then) =
      __$$SangeetSimpleArtistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetImageObject>? images});
}

/// @nodoc
class __$$SangeetSimpleArtistObjectImplCopyWithImpl<$Res>
    extends _$SangeetSimpleArtistObjectCopyWithImpl<$Res,
        _$SangeetSimpleArtistObjectImpl>
    implements _$$SangeetSimpleArtistObjectImplCopyWith<$Res> {
  __$$SangeetSimpleArtistObjectImplCopyWithImpl(
      _$SangeetSimpleArtistObjectImpl _value,
      $Res Function(_$SangeetSimpleArtistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? images = freezed,
  }) {
    return _then(_$SangeetSimpleArtistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      images: freezed == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetSimpleArtistObjectImpl implements _SangeetSimpleArtistObject {
  _$SangeetSimpleArtistObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SangeetImageObject>? images})
      : _images = images;

  factory _$SangeetSimpleArtistObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetSimpleArtistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SangeetImageObject>? _images;
  @override
  List<SangeetImageObject>? get images {
    final value = _images;
    if (value == null) return null;
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'SangeetSimpleArtistObject(id: $id, name: $name, externalUri: $externalUri, images: $images)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetSimpleArtistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._images, _images));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, externalUri,
      const DeepCollectionEquality().hash(_images));

  /// Create a copy of SangeetSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetSimpleArtistObjectImplCopyWith<_$SangeetSimpleArtistObjectImpl>
      get copyWith => __$$SangeetSimpleArtistObjectImplCopyWithImpl<
          _$SangeetSimpleArtistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetSimpleArtistObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetSimpleArtistObject implements SangeetSimpleArtistObject {
  factory _SangeetSimpleArtistObject(
          {required final String id,
          required final String name,
          required final String externalUri,
          final List<SangeetImageObject>? images}) =
      _$SangeetSimpleArtistObjectImpl;

  factory _SangeetSimpleArtistObject.fromJson(Map<String, dynamic> json) =
      _$SangeetSimpleArtistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SangeetImageObject>? get images;

  /// Create a copy of SangeetSimpleArtistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetSimpleArtistObjectImplCopyWith<_$SangeetSimpleArtistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetBrowseSectionObject<T> _$SangeetBrowseSectionObjectFromJson<T>(
    Map<String, dynamic> json, T Function(Object?) fromJsonT) {
  return _SangeetBrowseSectionObject<T>.fromJson(json, fromJsonT);
}

/// @nodoc
mixin _$SangeetBrowseSectionObject<T> {
  String get id => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  bool get browseMore => throw _privateConstructorUsedError;
  List<T> get items => throw _privateConstructorUsedError;

  /// Serializes this SangeetBrowseSectionObject to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) =>
      throw _privateConstructorUsedError;

  /// Create a copy of SangeetBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetBrowseSectionObjectCopyWith<T, SangeetBrowseSectionObject<T>>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetBrowseSectionObjectCopyWith<T, $Res> {
  factory $SangeetBrowseSectionObjectCopyWith(
          SangeetBrowseSectionObject<T> value,
          $Res Function(SangeetBrowseSectionObject<T>) then) =
      _$SangeetBrowseSectionObjectCopyWithImpl<T, $Res,
          SangeetBrowseSectionObject<T>>;
  @useResult
  $Res call(
      {String id,
      String title,
      String externalUri,
      bool browseMore,
      List<T> items});
}

/// @nodoc
class _$SangeetBrowseSectionObjectCopyWithImpl<T, $Res,
        $Val extends SangeetBrowseSectionObject<T>>
    implements $SangeetBrowseSectionObjectCopyWith<T, $Res> {
  _$SangeetBrowseSectionObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? externalUri = null,
    Object? browseMore = null,
    Object? items = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      browseMore: null == browseMore
          ? _value.browseMore
          : browseMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetBrowseSectionObjectImplCopyWith<T, $Res>
    implements $SangeetBrowseSectionObjectCopyWith<T, $Res> {
  factory _$$SangeetBrowseSectionObjectImplCopyWith(
          _$SangeetBrowseSectionObjectImpl<T> value,
          $Res Function(_$SangeetBrowseSectionObjectImpl<T>) then) =
      __$$SangeetBrowseSectionObjectImplCopyWithImpl<T, $Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String externalUri,
      bool browseMore,
      List<T> items});
}

/// @nodoc
class __$$SangeetBrowseSectionObjectImplCopyWithImpl<T, $Res>
    extends _$SangeetBrowseSectionObjectCopyWithImpl<T, $Res,
        _$SangeetBrowseSectionObjectImpl<T>>
    implements _$$SangeetBrowseSectionObjectImplCopyWith<T, $Res> {
  __$$SangeetBrowseSectionObjectImplCopyWithImpl(
      _$SangeetBrowseSectionObjectImpl<T> _value,
      $Res Function(_$SangeetBrowseSectionObjectImpl<T>) _then)
      : super(_value, _then);

  /// Create a copy of SangeetBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? externalUri = null,
    Object? browseMore = null,
    Object? items = null,
  }) {
    return _then(_$SangeetBrowseSectionObjectImpl<T>(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      browseMore: null == browseMore
          ? _value.browseMore
          : browseMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ));
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _$SangeetBrowseSectionObjectImpl<T>
    implements _SangeetBrowseSectionObject<T> {
  _$SangeetBrowseSectionObjectImpl(
      {required this.id,
      required this.title,
      required this.externalUri,
      required this.browseMore,
      required final List<T> items})
      : _items = items;

  factory _$SangeetBrowseSectionObjectImpl.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$$SangeetBrowseSectionObjectImplFromJson(json, fromJsonT);

  @override
  final String id;
  @override
  final String title;
  @override
  final String externalUri;
  @override
  final bool browseMore;
  final List<T> _items;
  @override
  List<T> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'SangeetBrowseSectionObject<$T>(id: $id, title: $title, externalUri: $externalUri, browseMore: $browseMore, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetBrowseSectionObjectImpl<T> &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.browseMore, browseMore) ||
                other.browseMore == browseMore) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, title, externalUri,
      browseMore, const DeepCollectionEquality().hash(_items));

  /// Create a copy of SangeetBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetBrowseSectionObjectImplCopyWith<T,
          _$SangeetBrowseSectionObjectImpl<T>>
      get copyWith => __$$SangeetBrowseSectionObjectImplCopyWithImpl<T,
          _$SangeetBrowseSectionObjectImpl<T>>(this, _$identity);

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$$SangeetBrowseSectionObjectImplToJson<T>(this, toJsonT);
  }
}

abstract class _SangeetBrowseSectionObject<T>
    implements SangeetBrowseSectionObject<T> {
  factory _SangeetBrowseSectionObject(
      {required final String id,
      required final String title,
      required final String externalUri,
      required final bool browseMore,
      required final List<T> items}) = _$SangeetBrowseSectionObjectImpl<T>;

  factory _SangeetBrowseSectionObject.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =
      _$SangeetBrowseSectionObjectImpl<T>.fromJson;

  @override
  String get id;
  @override
  String get title;
  @override
  String get externalUri;
  @override
  bool get browseMore;
  @override
  List<T> get items;

  /// Create a copy of SangeetBrowseSectionObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetBrowseSectionObjectImplCopyWith<T,
          _$SangeetBrowseSectionObjectImpl<T>>
      get copyWith => throw _privateConstructorUsedError;
}

MetadataFormFieldObject _$MetadataFormFieldObjectFromJson(
    Map<String, dynamic> json) {
  switch (json['objectType']) {
    case 'input':
      return MetadataFormFieldInputObject.fromJson(json);
    case 'text':
      return MetadataFormFieldTextObject.fromJson(json);

    default:
      throw CheckedFromJsonException(
          json,
          'objectType',
          'MetadataFormFieldObject',
          'Invalid union type "${json['objectType']}"!');
  }
}

/// @nodoc
mixin _$MetadataFormFieldObject {
  String get objectType => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)
        input,
    required TResult Function(String objectType, String text) text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult? Function(String objectType, String text)? text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult Function(String objectType, String text)? text,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MetadataFormFieldInputObject value) input,
    required TResult Function(MetadataFormFieldTextObject value) text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MetadataFormFieldInputObject value)? input,
    TResult? Function(MetadataFormFieldTextObject value)? text,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MetadataFormFieldInputObject value)? input,
    TResult Function(MetadataFormFieldTextObject value)? text,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this MetadataFormFieldObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetadataFormFieldObjectCopyWith<MetadataFormFieldObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataFormFieldObjectCopyWith<$Res> {
  factory $MetadataFormFieldObjectCopyWith(MetadataFormFieldObject value,
          $Res Function(MetadataFormFieldObject) then) =
      _$MetadataFormFieldObjectCopyWithImpl<$Res, MetadataFormFieldObject>;
  @useResult
  $Res call({String objectType});
}

/// @nodoc
class _$MetadataFormFieldObjectCopyWithImpl<$Res,
        $Val extends MetadataFormFieldObject>
    implements $MetadataFormFieldObjectCopyWith<$Res> {
  _$MetadataFormFieldObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectType = null,
  }) {
    return _then(_value.copyWith(
      objectType: null == objectType
          ? _value.objectType
          : objectType // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetadataFormFieldInputObjectImplCopyWith<$Res>
    implements $MetadataFormFieldObjectCopyWith<$Res> {
  factory _$$MetadataFormFieldInputObjectImplCopyWith(
          _$MetadataFormFieldInputObjectImpl value,
          $Res Function(_$MetadataFormFieldInputObjectImpl) then) =
      __$$MetadataFormFieldInputObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String objectType,
      String id,
      FormFieldVariant variant,
      String? placeholder,
      String? defaultValue,
      bool? required,
      String? regex});
}

/// @nodoc
class __$$MetadataFormFieldInputObjectImplCopyWithImpl<$Res>
    extends _$MetadataFormFieldObjectCopyWithImpl<$Res,
        _$MetadataFormFieldInputObjectImpl>
    implements _$$MetadataFormFieldInputObjectImplCopyWith<$Res> {
  __$$MetadataFormFieldInputObjectImplCopyWithImpl(
      _$MetadataFormFieldInputObjectImpl _value,
      $Res Function(_$MetadataFormFieldInputObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectType = null,
    Object? id = null,
    Object? variant = null,
    Object? placeholder = freezed,
    Object? defaultValue = freezed,
    Object? required = freezed,
    Object? regex = freezed,
  }) {
    return _then(_$MetadataFormFieldInputObjectImpl(
      objectType: null == objectType
          ? _value.objectType
          : objectType // ignore: cast_nullable_to_non_nullable
              as String,
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      variant: null == variant
          ? _value.variant
          : variant // ignore: cast_nullable_to_non_nullable
              as FormFieldVariant,
      placeholder: freezed == placeholder
          ? _value.placeholder
          : placeholder // ignore: cast_nullable_to_non_nullable
              as String?,
      defaultValue: freezed == defaultValue
          ? _value.defaultValue
          : defaultValue // ignore: cast_nullable_to_non_nullable
              as String?,
      required: freezed == required
          ? _value.required
          : required // ignore: cast_nullable_to_non_nullable
              as bool?,
      regex: freezed == regex
          ? _value.regex
          : regex // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MetadataFormFieldInputObjectImpl
    implements MetadataFormFieldInputObject {
  _$MetadataFormFieldInputObjectImpl(
      {required this.objectType,
      required this.id,
      this.variant = FormFieldVariant.text,
      this.placeholder,
      this.defaultValue,
      this.required,
      this.regex});

  factory _$MetadataFormFieldInputObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$MetadataFormFieldInputObjectImplFromJson(json);

  @override
  final String objectType;
  @override
  final String id;
  @override
  @JsonKey()
  final FormFieldVariant variant;
  @override
  final String? placeholder;
  @override
  final String? defaultValue;
  @override
  final bool? required;
  @override
  final String? regex;

  @override
  String toString() {
    return 'MetadataFormFieldObject.input(objectType: $objectType, id: $id, variant: $variant, placeholder: $placeholder, defaultValue: $defaultValue, required: $required, regex: $regex)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataFormFieldInputObjectImpl &&
            (identical(other.objectType, objectType) ||
                other.objectType == objectType) &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.variant, variant) || other.variant == variant) &&
            (identical(other.placeholder, placeholder) ||
                other.placeholder == placeholder) &&
            (identical(other.defaultValue, defaultValue) ||
                other.defaultValue == defaultValue) &&
            (identical(other.required, required) ||
                other.required == required) &&
            (identical(other.regex, regex) || other.regex == regex));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, objectType, id, variant,
      placeholder, defaultValue, required, regex);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataFormFieldInputObjectImplCopyWith<
          _$MetadataFormFieldInputObjectImpl>
      get copyWith => __$$MetadataFormFieldInputObjectImplCopyWithImpl<
          _$MetadataFormFieldInputObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)
        input,
    required TResult Function(String objectType, String text) text,
  }) {
    return input(
        objectType, id, variant, placeholder, defaultValue, required, regex);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult? Function(String objectType, String text)? text,
  }) {
    return input?.call(
        objectType, id, variant, placeholder, defaultValue, required, regex);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult Function(String objectType, String text)? text,
    required TResult orElse(),
  }) {
    if (input != null) {
      return input(
          objectType, id, variant, placeholder, defaultValue, required, regex);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MetadataFormFieldInputObject value) input,
    required TResult Function(MetadataFormFieldTextObject value) text,
  }) {
    return input(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MetadataFormFieldInputObject value)? input,
    TResult? Function(MetadataFormFieldTextObject value)? text,
  }) {
    return input?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MetadataFormFieldInputObject value)? input,
    TResult Function(MetadataFormFieldTextObject value)? text,
    required TResult orElse(),
  }) {
    if (input != null) {
      return input(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataFormFieldInputObjectImplToJson(
      this,
    );
  }
}

abstract class MetadataFormFieldInputObject implements MetadataFormFieldObject {
  factory MetadataFormFieldInputObject(
      {required final String objectType,
      required final String id,
      final FormFieldVariant variant,
      final String? placeholder,
      final String? defaultValue,
      final bool? required,
      final String? regex}) = _$MetadataFormFieldInputObjectImpl;

  factory MetadataFormFieldInputObject.fromJson(Map<String, dynamic> json) =
      _$MetadataFormFieldInputObjectImpl.fromJson;

  @override
  String get objectType;
  String get id;
  FormFieldVariant get variant;
  String? get placeholder;
  String? get defaultValue;
  bool? get required;
  String? get regex;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataFormFieldInputObjectImplCopyWith<
          _$MetadataFormFieldInputObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$MetadataFormFieldTextObjectImplCopyWith<$Res>
    implements $MetadataFormFieldObjectCopyWith<$Res> {
  factory _$$MetadataFormFieldTextObjectImplCopyWith(
          _$MetadataFormFieldTextObjectImpl value,
          $Res Function(_$MetadataFormFieldTextObjectImpl) then) =
      __$$MetadataFormFieldTextObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String objectType, String text});
}

/// @nodoc
class __$$MetadataFormFieldTextObjectImplCopyWithImpl<$Res>
    extends _$MetadataFormFieldObjectCopyWithImpl<$Res,
        _$MetadataFormFieldTextObjectImpl>
    implements _$$MetadataFormFieldTextObjectImplCopyWith<$Res> {
  __$$MetadataFormFieldTextObjectImplCopyWithImpl(
      _$MetadataFormFieldTextObjectImpl _value,
      $Res Function(_$MetadataFormFieldTextObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? objectType = null,
    Object? text = null,
  }) {
    return _then(_$MetadataFormFieldTextObjectImpl(
      objectType: null == objectType
          ? _value.objectType
          : objectType // ignore: cast_nullable_to_non_nullable
              as String,
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MetadataFormFieldTextObjectImpl implements MetadataFormFieldTextObject {
  _$MetadataFormFieldTextObjectImpl(
      {required this.objectType, required this.text});

  factory _$MetadataFormFieldTextObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$MetadataFormFieldTextObjectImplFromJson(json);

  @override
  final String objectType;
  @override
  final String text;

  @override
  String toString() {
    return 'MetadataFormFieldObject.text(objectType: $objectType, text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataFormFieldTextObjectImpl &&
            (identical(other.objectType, objectType) ||
                other.objectType == objectType) &&
            (identical(other.text, text) || other.text == text));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, objectType, text);

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataFormFieldTextObjectImplCopyWith<_$MetadataFormFieldTextObjectImpl>
      get copyWith => __$$MetadataFormFieldTextObjectImplCopyWithImpl<
          _$MetadataFormFieldTextObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)
        input,
    required TResult Function(String objectType, String text) text,
  }) {
    return text(objectType, this.text);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult? Function(String objectType, String text)? text,
  }) {
    return text?.call(objectType, this.text);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String objectType,
            String id,
            FormFieldVariant variant,
            String? placeholder,
            String? defaultValue,
            bool? required,
            String? regex)?
        input,
    TResult Function(String objectType, String text)? text,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(objectType, this.text);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(MetadataFormFieldInputObject value) input,
    required TResult Function(MetadataFormFieldTextObject value) text,
  }) {
    return text(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(MetadataFormFieldInputObject value)? input,
    TResult? Function(MetadataFormFieldTextObject value)? text,
  }) {
    return text?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(MetadataFormFieldInputObject value)? input,
    TResult Function(MetadataFormFieldTextObject value)? text,
    required TResult orElse(),
  }) {
    if (text != null) {
      return text(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataFormFieldTextObjectImplToJson(
      this,
    );
  }
}

abstract class MetadataFormFieldTextObject implements MetadataFormFieldObject {
  factory MetadataFormFieldTextObject(
      {required final String objectType,
      required final String text}) = _$MetadataFormFieldTextObjectImpl;

  factory MetadataFormFieldTextObject.fromJson(Map<String, dynamic> json) =
      _$MetadataFormFieldTextObjectImpl.fromJson;

  @override
  String get objectType;
  String get text;

  /// Create a copy of MetadataFormFieldObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataFormFieldTextObjectImplCopyWith<_$MetadataFormFieldTextObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetImageObject _$SangeetImageObjectFromJson(Map<String, dynamic> json) {
  return _SangeetImageObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetImageObject {
  String get url => throw _privateConstructorUsedError;
  int? get width => throw _privateConstructorUsedError;
  int? get height => throw _privateConstructorUsedError;

  /// Serializes this SangeetImageObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetImageObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetImageObjectCopyWith<SangeetImageObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetImageObjectCopyWith<$Res> {
  factory $SangeetImageObjectCopyWith(
          SangeetImageObject value, $Res Function(SangeetImageObject) then) =
      _$SangeetImageObjectCopyWithImpl<$Res, SangeetImageObject>;
  @useResult
  $Res call({String url, int? width, int? height});
}

/// @nodoc
class _$SangeetImageObjectCopyWithImpl<$Res, $Val extends SangeetImageObject>
    implements $SangeetImageObjectCopyWith<$Res> {
  _$SangeetImageObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetImageObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_value.copyWith(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetImageObjectImplCopyWith<$Res>
    implements $SangeetImageObjectCopyWith<$Res> {
  factory _$$SangeetImageObjectImplCopyWith(_$SangeetImageObjectImpl value,
          $Res Function(_$SangeetImageObjectImpl) then) =
      __$$SangeetImageObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String url, int? width, int? height});
}

/// @nodoc
class __$$SangeetImageObjectImplCopyWithImpl<$Res>
    extends _$SangeetImageObjectCopyWithImpl<$Res, _$SangeetImageObjectImpl>
    implements _$$SangeetImageObjectImplCopyWith<$Res> {
  __$$SangeetImageObjectImplCopyWithImpl(_$SangeetImageObjectImpl _value,
      $Res Function(_$SangeetImageObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetImageObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? url = null,
    Object? width = freezed,
    Object? height = freezed,
  }) {
    return _then(_$SangeetImageObjectImpl(
      url: null == url
          ? _value.url
          : url // ignore: cast_nullable_to_non_nullable
              as String,
      width: freezed == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as int?,
      height: freezed == height
          ? _value.height
          : height // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetImageObjectImpl implements _SangeetImageObject {
  _$SangeetImageObjectImpl({required this.url, this.width, this.height});

  factory _$SangeetImageObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetImageObjectImplFromJson(json);

  @override
  final String url;
  @override
  final int? width;
  @override
  final int? height;

  @override
  String toString() {
    return 'SangeetImageObject(url: $url, width: $width, height: $height)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetImageObjectImpl &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.height, height) || other.height == height));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, url, width, height);

  /// Create a copy of SangeetImageObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetImageObjectImplCopyWith<_$SangeetImageObjectImpl> get copyWith =>
      __$$SangeetImageObjectImplCopyWithImpl<_$SangeetImageObjectImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetImageObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetImageObject implements SangeetImageObject {
  factory _SangeetImageObject(
      {required final String url,
      final int? width,
      final int? height}) = _$SangeetImageObjectImpl;

  factory _SangeetImageObject.fromJson(Map<String, dynamic> json) =
      _$SangeetImageObjectImpl.fromJson;

  @override
  String get url;
  @override
  int? get width;
  @override
  int? get height;

  /// Create a copy of SangeetImageObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetImageObjectImplCopyWith<_$SangeetImageObjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SangeetPaginationResponseObject<T> _$SangeetPaginationResponseObjectFromJson<T>(
    Map<String, dynamic> json, T Function(Object?) fromJsonT) {
  return _SangeetPaginationResponseObject<T>.fromJson(json, fromJsonT);
}

/// @nodoc
mixin _$SangeetPaginationResponseObject<T> {
  int get limit => throw _privateConstructorUsedError;
  int? get nextOffset => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;
  List<T> get items => throw _privateConstructorUsedError;

  /// Serializes this SangeetPaginationResponseObject to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) =>
      throw _privateConstructorUsedError;

  /// Create a copy of SangeetPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetPaginationResponseObjectCopyWith<T,
          SangeetPaginationResponseObject<T>>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetPaginationResponseObjectCopyWith<T, $Res> {
  factory $SangeetPaginationResponseObjectCopyWith(
          SangeetPaginationResponseObject<T> value,
          $Res Function(SangeetPaginationResponseObject<T>) then) =
      _$SangeetPaginationResponseObjectCopyWithImpl<T, $Res,
          SangeetPaginationResponseObject<T>>;
  @useResult
  $Res call(
      {int limit, int? nextOffset, int total, bool hasMore, List<T> items});
}

/// @nodoc
class _$SangeetPaginationResponseObjectCopyWithImpl<T, $Res,
        $Val extends SangeetPaginationResponseObject<T>>
    implements $SangeetPaginationResponseObjectCopyWith<T, $Res> {
  _$SangeetPaginationResponseObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? limit = null,
    Object? nextOffset = freezed,
    Object? total = null,
    Object? hasMore = null,
    Object? items = null,
  }) {
    return _then(_value.copyWith(
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      nextOffset: freezed == nextOffset
          ? _value.nextOffset
          : nextOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetPaginationResponseObjectImplCopyWith<T, $Res>
    implements $SangeetPaginationResponseObjectCopyWith<T, $Res> {
  factory _$$SangeetPaginationResponseObjectImplCopyWith(
          _$SangeetPaginationResponseObjectImpl<T> value,
          $Res Function(_$SangeetPaginationResponseObjectImpl<T>) then) =
      __$$SangeetPaginationResponseObjectImplCopyWithImpl<T, $Res>;
  @override
  @useResult
  $Res call(
      {int limit, int? nextOffset, int total, bool hasMore, List<T> items});
}

/// @nodoc
class __$$SangeetPaginationResponseObjectImplCopyWithImpl<T, $Res>
    extends _$SangeetPaginationResponseObjectCopyWithImpl<T, $Res,
        _$SangeetPaginationResponseObjectImpl<T>>
    implements _$$SangeetPaginationResponseObjectImplCopyWith<T, $Res> {
  __$$SangeetPaginationResponseObjectImplCopyWithImpl(
      _$SangeetPaginationResponseObjectImpl<T> _value,
      $Res Function(_$SangeetPaginationResponseObjectImpl<T>) _then)
      : super(_value, _then);

  /// Create a copy of SangeetPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? limit = null,
    Object? nextOffset = freezed,
    Object? total = null,
    Object? hasMore = null,
    Object? items = null,
  }) {
    return _then(_$SangeetPaginationResponseObjectImpl<T>(
      limit: null == limit
          ? _value.limit
          : limit // ignore: cast_nullable_to_non_nullable
              as int,
      nextOffset: freezed == nextOffset
          ? _value.nextOffset
          : nextOffset // ignore: cast_nullable_to_non_nullable
              as int?,
      total: null == total
          ? _value.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      items: null == items
          ? _value._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<T>,
    ));
  }
}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)
class _$SangeetPaginationResponseObjectImpl<T>
    implements _SangeetPaginationResponseObject<T> {
  _$SangeetPaginationResponseObjectImpl(
      {required this.limit,
      required this.nextOffset,
      required this.total,
      required this.hasMore,
      required final List<T> items})
      : _items = items;

  factory _$SangeetPaginationResponseObjectImpl.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =>
      _$$SangeetPaginationResponseObjectImplFromJson(json, fromJsonT);

  @override
  final int limit;
  @override
  final int? nextOffset;
  @override
  final int total;
  @override
  final bool hasMore;
  final List<T> _items;
  @override
  List<T> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'SangeetPaginationResponseObject<$T>(limit: $limit, nextOffset: $nextOffset, total: $total, hasMore: $hasMore, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetPaginationResponseObjectImpl<T> &&
            (identical(other.limit, limit) || other.limit == limit) &&
            (identical(other.nextOffset, nextOffset) ||
                other.nextOffset == nextOffset) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, limit, nextOffset, total,
      hasMore, const DeepCollectionEquality().hash(_items));

  /// Create a copy of SangeetPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetPaginationResponseObjectImplCopyWith<T,
          _$SangeetPaginationResponseObjectImpl<T>>
      get copyWith => __$$SangeetPaginationResponseObjectImplCopyWithImpl<T,
          _$SangeetPaginationResponseObjectImpl<T>>(this, _$identity);

  @override
  Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
    return _$$SangeetPaginationResponseObjectImplToJson<T>(this, toJsonT);
  }
}

abstract class _SangeetPaginationResponseObject<T>
    implements SangeetPaginationResponseObject<T> {
  factory _SangeetPaginationResponseObject(
      {required final int limit,
      required final int? nextOffset,
      required final int total,
      required final bool hasMore,
      required final List<T> items}) = _$SangeetPaginationResponseObjectImpl<T>;

  factory _SangeetPaginationResponseObject.fromJson(
          Map<String, dynamic> json, T Function(Object?) fromJsonT) =
      _$SangeetPaginationResponseObjectImpl<T>.fromJson;

  @override
  int get limit;
  @override
  int? get nextOffset;
  @override
  int get total;
  @override
  bool get hasMore;
  @override
  List<T> get items;

  /// Create a copy of SangeetPaginationResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetPaginationResponseObjectImplCopyWith<T,
          _$SangeetPaginationResponseObjectImpl<T>>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetFullPlaylistObject _$SangeetFullPlaylistObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetFullPlaylistObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetFullPlaylistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  SangeetUserObject get owner => throw _privateConstructorUsedError;
  List<SangeetImageObject> get images => throw _privateConstructorUsedError;
  List<SangeetUserObject> get collaborators =>
      throw _privateConstructorUsedError;
  bool get collaborative => throw _privateConstructorUsedError;
  bool get public => throw _privateConstructorUsedError;

  /// Serializes this SangeetFullPlaylistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetFullPlaylistObjectCopyWith<SangeetFullPlaylistObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetFullPlaylistObjectCopyWith<$Res> {
  factory $SangeetFullPlaylistObjectCopyWith(SangeetFullPlaylistObject value,
          $Res Function(SangeetFullPlaylistObject) then) =
      _$SangeetFullPlaylistObjectCopyWithImpl<$Res, SangeetFullPlaylistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SangeetUserObject owner,
      List<SangeetImageObject> images,
      List<SangeetUserObject> collaborators,
      bool collaborative,
      bool public});

  $SangeetUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class _$SangeetFullPlaylistObjectCopyWithImpl<$Res,
        $Val extends SangeetFullPlaylistObject>
    implements $SangeetFullPlaylistObjectCopyWith<$Res> {
  _$SangeetFullPlaylistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
    Object? collaborators = null,
    Object? collaborative = null,
    Object? public = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SangeetUserObject,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      collaborators: null == collaborators
          ? _value.collaborators
          : collaborators // ignore: cast_nullable_to_non_nullable
              as List<SangeetUserObject>,
      collaborative: null == collaborative
          ? _value.collaborative
          : collaborative // ignore: cast_nullable_to_non_nullable
              as bool,
      public: null == public
          ? _value.public
          : public // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of SangeetFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SangeetUserObjectCopyWith<$Res> get owner {
    return $SangeetUserObjectCopyWith<$Res>(_value.owner, (value) {
      return _then(_value.copyWith(owner: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SangeetFullPlaylistObjectImplCopyWith<$Res>
    implements $SangeetFullPlaylistObjectCopyWith<$Res> {
  factory _$$SangeetFullPlaylistObjectImplCopyWith(
          _$SangeetFullPlaylistObjectImpl value,
          $Res Function(_$SangeetFullPlaylistObjectImpl) then) =
      __$$SangeetFullPlaylistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SangeetUserObject owner,
      List<SangeetImageObject> images,
      List<SangeetUserObject> collaborators,
      bool collaborative,
      bool public});

  @override
  $SangeetUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class __$$SangeetFullPlaylistObjectImplCopyWithImpl<$Res>
    extends _$SangeetFullPlaylistObjectCopyWithImpl<$Res,
        _$SangeetFullPlaylistObjectImpl>
    implements _$$SangeetFullPlaylistObjectImplCopyWith<$Res> {
  __$$SangeetFullPlaylistObjectImplCopyWithImpl(
      _$SangeetFullPlaylistObjectImpl _value,
      $Res Function(_$SangeetFullPlaylistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
    Object? collaborators = null,
    Object? collaborative = null,
    Object? public = null,
  }) {
    return _then(_$SangeetFullPlaylistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SangeetUserObject,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      collaborators: null == collaborators
          ? _value._collaborators
          : collaborators // ignore: cast_nullable_to_non_nullable
              as List<SangeetUserObject>,
      collaborative: null == collaborative
          ? _value.collaborative
          : collaborative // ignore: cast_nullable_to_non_nullable
              as bool,
      public: null == public
          ? _value.public
          : public // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetFullPlaylistObjectImpl implements _SangeetFullPlaylistObject {
  _$SangeetFullPlaylistObjectImpl(
      {required this.id,
      required this.name,
      required this.description,
      required this.externalUri,
      required this.owner,
      final List<SangeetImageObject> images = const [],
      final List<SangeetUserObject> collaborators = const [],
      this.collaborative = false,
      this.public = false})
      : _images = images,
        _collaborators = collaborators;

  factory _$SangeetFullPlaylistObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetFullPlaylistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String externalUri;
  @override
  final SangeetUserObject owner;
  final List<SangeetImageObject> _images;
  @override
  @JsonKey()
  List<SangeetImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  final List<SangeetUserObject> _collaborators;
  @override
  @JsonKey()
  List<SangeetUserObject> get collaborators {
    if (_collaborators is EqualUnmodifiableListView) return _collaborators;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_collaborators);
  }

  @override
  @JsonKey()
  final bool collaborative;
  @override
  @JsonKey()
  final bool public;

  @override
  String toString() {
    return 'SangeetFullPlaylistObject(id: $id, name: $name, description: $description, externalUri: $externalUri, owner: $owner, images: $images, collaborators: $collaborators, collaborative: $collaborative, public: $public)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetFullPlaylistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            const DeepCollectionEquality()
                .equals(other._collaborators, _collaborators) &&
            (identical(other.collaborative, collaborative) ||
                other.collaborative == collaborative) &&
            (identical(other.public, public) || other.public == public));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      description,
      externalUri,
      owner,
      const DeepCollectionEquality().hash(_images),
      const DeepCollectionEquality().hash(_collaborators),
      collaborative,
      public);

  /// Create a copy of SangeetFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetFullPlaylistObjectImplCopyWith<_$SangeetFullPlaylistObjectImpl>
      get copyWith => __$$SangeetFullPlaylistObjectImplCopyWithImpl<
          _$SangeetFullPlaylistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetFullPlaylistObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetFullPlaylistObject implements SangeetFullPlaylistObject {
  factory _SangeetFullPlaylistObject(
      {required final String id,
      required final String name,
      required final String description,
      required final String externalUri,
      required final SangeetUserObject owner,
      final List<SangeetImageObject> images,
      final List<SangeetUserObject> collaborators,
      final bool collaborative,
      final bool public}) = _$SangeetFullPlaylistObjectImpl;

  factory _SangeetFullPlaylistObject.fromJson(Map<String, dynamic> json) =
      _$SangeetFullPlaylistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String get externalUri;
  @override
  SangeetUserObject get owner;
  @override
  List<SangeetImageObject> get images;
  @override
  List<SangeetUserObject> get collaborators;
  @override
  bool get collaborative;
  @override
  bool get public;

  /// Create a copy of SangeetFullPlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetFullPlaylistObjectImplCopyWith<_$SangeetFullPlaylistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetSimplePlaylistObject _$SangeetSimplePlaylistObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetSimplePlaylistObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetSimplePlaylistObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  SangeetUserObject get owner => throw _privateConstructorUsedError;
  List<SangeetImageObject> get images => throw _privateConstructorUsedError;

  /// Serializes this SangeetSimplePlaylistObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetSimplePlaylistObjectCopyWith<SangeetSimplePlaylistObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetSimplePlaylistObjectCopyWith<$Res> {
  factory $SangeetSimplePlaylistObjectCopyWith(
          SangeetSimplePlaylistObject value,
          $Res Function(SangeetSimplePlaylistObject) then) =
      _$SangeetSimplePlaylistObjectCopyWithImpl<$Res,
          SangeetSimplePlaylistObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SangeetUserObject owner,
      List<SangeetImageObject> images});

  $SangeetUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class _$SangeetSimplePlaylistObjectCopyWithImpl<$Res,
        $Val extends SangeetSimplePlaylistObject>
    implements $SangeetSimplePlaylistObjectCopyWith<$Res> {
  _$SangeetSimplePlaylistObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SangeetUserObject,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
    ) as $Val);
  }

  /// Create a copy of SangeetSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SangeetUserObjectCopyWith<$Res> get owner {
    return $SangeetUserObjectCopyWith<$Res>(_value.owner, (value) {
      return _then(_value.copyWith(owner: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SangeetSimplePlaylistObjectImplCopyWith<$Res>
    implements $SangeetSimplePlaylistObjectCopyWith<$Res> {
  factory _$$SangeetSimplePlaylistObjectImplCopyWith(
          _$SangeetSimplePlaylistObjectImpl value,
          $Res Function(_$SangeetSimplePlaylistObjectImpl) then) =
      __$$SangeetSimplePlaylistObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String description,
      String externalUri,
      SangeetUserObject owner,
      List<SangeetImageObject> images});

  @override
  $SangeetUserObjectCopyWith<$Res> get owner;
}

/// @nodoc
class __$$SangeetSimplePlaylistObjectImplCopyWithImpl<$Res>
    extends _$SangeetSimplePlaylistObjectCopyWithImpl<$Res,
        _$SangeetSimplePlaylistObjectImpl>
    implements _$$SangeetSimplePlaylistObjectImplCopyWith<$Res> {
  __$$SangeetSimplePlaylistObjectImplCopyWithImpl(
      _$SangeetSimplePlaylistObjectImpl _value,
      $Res Function(_$SangeetSimplePlaylistObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? description = null,
    Object? externalUri = null,
    Object? owner = null,
    Object? images = null,
  }) {
    return _then(_$SangeetSimplePlaylistObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as SangeetUserObject,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetSimplePlaylistObjectImpl
    implements _SangeetSimplePlaylistObject {
  _$SangeetSimplePlaylistObjectImpl(
      {required this.id,
      required this.name,
      required this.description,
      required this.externalUri,
      required this.owner,
      final List<SangeetImageObject> images = const []})
      : _images = images;

  factory _$SangeetSimplePlaylistObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetSimplePlaylistObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String description;
  @override
  final String externalUri;
  @override
  final SangeetUserObject owner;
  final List<SangeetImageObject> _images;
  @override
  @JsonKey()
  List<SangeetImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  String toString() {
    return 'SangeetSimplePlaylistObject(id: $id, name: $name, description: $description, externalUri: $externalUri, owner: $owner, images: $images)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetSimplePlaylistObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            const DeepCollectionEquality().equals(other._images, _images));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, description,
      externalUri, owner, const DeepCollectionEquality().hash(_images));

  /// Create a copy of SangeetSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetSimplePlaylistObjectImplCopyWith<_$SangeetSimplePlaylistObjectImpl>
      get copyWith => __$$SangeetSimplePlaylistObjectImplCopyWithImpl<
          _$SangeetSimplePlaylistObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetSimplePlaylistObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetSimplePlaylistObject
    implements SangeetSimplePlaylistObject {
  factory _SangeetSimplePlaylistObject(
          {required final String id,
          required final String name,
          required final String description,
          required final String externalUri,
          required final SangeetUserObject owner,
          final List<SangeetImageObject> images}) =
      _$SangeetSimplePlaylistObjectImpl;

  factory _SangeetSimplePlaylistObject.fromJson(Map<String, dynamic> json) =
      _$SangeetSimplePlaylistObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get description;
  @override
  String get externalUri;
  @override
  SangeetUserObject get owner;
  @override
  List<SangeetImageObject> get images;

  /// Create a copy of SangeetSimplePlaylistObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetSimplePlaylistObjectImplCopyWith<_$SangeetSimplePlaylistObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetSearchResponseObject _$SangeetSearchResponseObjectFromJson(
    Map<String, dynamic> json) {
  return _SangeetSearchResponseObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetSearchResponseObject {
  List<SangeetSimpleAlbumObject> get albums =>
      throw _privateConstructorUsedError;
  List<SangeetFullArtistObject> get artists =>
      throw _privateConstructorUsedError;
  List<SangeetSimplePlaylistObject> get playlists =>
      throw _privateConstructorUsedError;
  List<SangeetFullTrackObject> get tracks => throw _privateConstructorUsedError;

  /// Serializes this SangeetSearchResponseObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetSearchResponseObjectCopyWith<SangeetSearchResponseObject>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetSearchResponseObjectCopyWith<$Res> {
  factory $SangeetSearchResponseObjectCopyWith(
          SangeetSearchResponseObject value,
          $Res Function(SangeetSearchResponseObject) then) =
      _$SangeetSearchResponseObjectCopyWithImpl<$Res,
          SangeetSearchResponseObject>;
  @useResult
  $Res call(
      {List<SangeetSimpleAlbumObject> albums,
      List<SangeetFullArtistObject> artists,
      List<SangeetSimplePlaylistObject> playlists,
      List<SangeetFullTrackObject> tracks});
}

/// @nodoc
class _$SangeetSearchResponseObjectCopyWithImpl<$Res,
        $Val extends SangeetSearchResponseObject>
    implements $SangeetSearchResponseObjectCopyWith<$Res> {
  _$SangeetSearchResponseObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? albums = null,
    Object? artists = null,
    Object? playlists = null,
    Object? tracks = null,
  }) {
    return _then(_value.copyWith(
      albums: null == albums
          ? _value.albums
          : albums // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleAlbumObject>,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetFullArtistObject>,
      playlists: null == playlists
          ? _value.playlists
          : playlists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimplePlaylistObject>,
      tracks: null == tracks
          ? _value.tracks
          : tracks // ignore: cast_nullable_to_non_nullable
              as List<SangeetFullTrackObject>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetSearchResponseObjectImplCopyWith<$Res>
    implements $SangeetSearchResponseObjectCopyWith<$Res> {
  factory _$$SangeetSearchResponseObjectImplCopyWith(
          _$SangeetSearchResponseObjectImpl value,
          $Res Function(_$SangeetSearchResponseObjectImpl) then) =
      __$$SangeetSearchResponseObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<SangeetSimpleAlbumObject> albums,
      List<SangeetFullArtistObject> artists,
      List<SangeetSimplePlaylistObject> playlists,
      List<SangeetFullTrackObject> tracks});
}

/// @nodoc
class __$$SangeetSearchResponseObjectImplCopyWithImpl<$Res>
    extends _$SangeetSearchResponseObjectCopyWithImpl<$Res,
        _$SangeetSearchResponseObjectImpl>
    implements _$$SangeetSearchResponseObjectImplCopyWith<$Res> {
  __$$SangeetSearchResponseObjectImplCopyWithImpl(
      _$SangeetSearchResponseObjectImpl _value,
      $Res Function(_$SangeetSearchResponseObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? albums = null,
    Object? artists = null,
    Object? playlists = null,
    Object? tracks = null,
  }) {
    return _then(_$SangeetSearchResponseObjectImpl(
      albums: null == albums
          ? _value._albums
          : albums // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleAlbumObject>,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetFullArtistObject>,
      playlists: null == playlists
          ? _value._playlists
          : playlists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimplePlaylistObject>,
      tracks: null == tracks
          ? _value._tracks
          : tracks // ignore: cast_nullable_to_non_nullable
              as List<SangeetFullTrackObject>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetSearchResponseObjectImpl
    implements _SangeetSearchResponseObject {
  _$SangeetSearchResponseObjectImpl(
      {required final List<SangeetSimpleAlbumObject> albums,
      required final List<SangeetFullArtistObject> artists,
      required final List<SangeetSimplePlaylistObject> playlists,
      required final List<SangeetFullTrackObject> tracks})
      : _albums = albums,
        _artists = artists,
        _playlists = playlists,
        _tracks = tracks;

  factory _$SangeetSearchResponseObjectImpl.fromJson(
          Map<String, dynamic> json) =>
      _$$SangeetSearchResponseObjectImplFromJson(json);

  final List<SangeetSimpleAlbumObject> _albums;
  @override
  List<SangeetSimpleAlbumObject> get albums {
    if (_albums is EqualUnmodifiableListView) return _albums;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_albums);
  }

  final List<SangeetFullArtistObject> _artists;
  @override
  List<SangeetFullArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  final List<SangeetSimplePlaylistObject> _playlists;
  @override
  List<SangeetSimplePlaylistObject> get playlists {
    if (_playlists is EqualUnmodifiableListView) return _playlists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_playlists);
  }

  final List<SangeetFullTrackObject> _tracks;
  @override
  List<SangeetFullTrackObject> get tracks {
    if (_tracks is EqualUnmodifiableListView) return _tracks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tracks);
  }

  @override
  String toString() {
    return 'SangeetSearchResponseObject(albums: $albums, artists: $artists, playlists: $playlists, tracks: $tracks)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetSearchResponseObjectImpl &&
            const DeepCollectionEquality().equals(other._albums, _albums) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            const DeepCollectionEquality()
                .equals(other._playlists, _playlists) &&
            const DeepCollectionEquality().equals(other._tracks, _tracks));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_albums),
      const DeepCollectionEquality().hash(_artists),
      const DeepCollectionEquality().hash(_playlists),
      const DeepCollectionEquality().hash(_tracks));

  /// Create a copy of SangeetSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetSearchResponseObjectImplCopyWith<_$SangeetSearchResponseObjectImpl>
      get copyWith => __$$SangeetSearchResponseObjectImplCopyWithImpl<
          _$SangeetSearchResponseObjectImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetSearchResponseObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetSearchResponseObject
    implements SangeetSearchResponseObject {
  factory _SangeetSearchResponseObject(
          {required final List<SangeetSimpleAlbumObject> albums,
          required final List<SangeetFullArtistObject> artists,
          required final List<SangeetSimplePlaylistObject> playlists,
          required final List<SangeetFullTrackObject> tracks}) =
      _$SangeetSearchResponseObjectImpl;

  factory _SangeetSearchResponseObject.fromJson(Map<String, dynamic> json) =
      _$SangeetSearchResponseObjectImpl.fromJson;

  @override
  List<SangeetSimpleAlbumObject> get albums;
  @override
  List<SangeetFullArtistObject> get artists;
  @override
  List<SangeetSimplePlaylistObject> get playlists;
  @override
  List<SangeetFullTrackObject> get tracks;

  /// Create a copy of SangeetSearchResponseObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetSearchResponseObjectImplCopyWith<_$SangeetSearchResponseObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetTrackObject _$SangeetTrackObjectFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'local':
      return SangeetLocalTrackObject.fromJson(json);
    case 'full':
      return SangeetFullTrackObject.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'SangeetTrackObject',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$SangeetTrackObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;
  List<SangeetSimpleArtistObject> get artists =>
      throw _privateConstructorUsedError;
  SangeetSimpleAlbumObject get album => throw _privateConstructorUsedError;
  int get durationMs => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)
        local,
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)
        full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)?
        full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)?
        full,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SangeetLocalTrackObject value) local,
    required TResult Function(SangeetFullTrackObject value) full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SangeetLocalTrackObject value)? local,
    TResult? Function(SangeetFullTrackObject value)? full,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SangeetLocalTrackObject value)? local,
    TResult Function(SangeetFullTrackObject value)? full,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Serializes this SangeetTrackObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetTrackObjectCopyWith<SangeetTrackObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetTrackObjectCopyWith<$Res> {
  factory $SangeetTrackObjectCopyWith(
          SangeetTrackObject value, $Res Function(SangeetTrackObject) then) =
      _$SangeetTrackObjectCopyWithImpl<$Res, SangeetTrackObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetSimpleArtistObject> artists,
      SangeetSimpleAlbumObject album,
      int durationMs});

  $SangeetSimpleAlbumObjectCopyWith<$Res> get album;
}

/// @nodoc
class _$SangeetTrackObjectCopyWithImpl<$Res, $Val extends SangeetTrackObject>
    implements $SangeetTrackObjectCopyWith<$Res> {
  _$SangeetTrackObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? album = null,
    Object? durationMs = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value.artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      album: null == album
          ? _value.album
          : album // ignore: cast_nullable_to_non_nullable
              as SangeetSimpleAlbumObject,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SangeetSimpleAlbumObjectCopyWith<$Res> get album {
    return $SangeetSimpleAlbumObjectCopyWith<$Res>(_value.album, (value) {
      return _then(_value.copyWith(album: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SangeetLocalTrackObjectImplCopyWith<$Res>
    implements $SangeetTrackObjectCopyWith<$Res> {
  factory _$$SangeetLocalTrackObjectImplCopyWith(
          _$SangeetLocalTrackObjectImpl value,
          $Res Function(_$SangeetLocalTrackObjectImpl) then) =
      __$$SangeetLocalTrackObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetSimpleArtistObject> artists,
      SangeetSimpleAlbumObject album,
      int durationMs,
      String path});

  @override
  $SangeetSimpleAlbumObjectCopyWith<$Res> get album;
}

/// @nodoc
class __$$SangeetLocalTrackObjectImplCopyWithImpl<$Res>
    extends _$SangeetTrackObjectCopyWithImpl<$Res,
        _$SangeetLocalTrackObjectImpl>
    implements _$$SangeetLocalTrackObjectImplCopyWith<$Res> {
  __$$SangeetLocalTrackObjectImplCopyWithImpl(
      _$SangeetLocalTrackObjectImpl _value,
      $Res Function(_$SangeetLocalTrackObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? album = null,
    Object? durationMs = null,
    Object? path = null,
  }) {
    return _then(_$SangeetLocalTrackObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      album: null == album
          ? _value.album
          : album // ignore: cast_nullable_to_non_nullable
              as SangeetSimpleAlbumObject,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      path: null == path
          ? _value.path
          : path // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetLocalTrackObjectImpl implements SangeetLocalTrackObject {
  _$SangeetLocalTrackObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SangeetSimpleArtistObject> artists = const [],
      required this.album,
      required this.durationMs,
      required this.path,
      final String? $type})
      : _artists = artists,
        $type = $type ?? 'local';

  factory _$SangeetLocalTrackObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetLocalTrackObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SangeetSimpleArtistObject> _artists;
  @override
  @JsonKey()
  List<SangeetSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  @override
  final SangeetSimpleAlbumObject album;
  @override
  final int durationMs;
  @override
  final String path;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SangeetTrackObject.local(id: $id, name: $name, externalUri: $externalUri, artists: $artists, album: $album, durationMs: $durationMs, path: $path)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetLocalTrackObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.path, path) || other.path == path));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, externalUri,
      const DeepCollectionEquality().hash(_artists), album, durationMs, path);

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetLocalTrackObjectImplCopyWith<_$SangeetLocalTrackObjectImpl>
      get copyWith => __$$SangeetLocalTrackObjectImplCopyWithImpl<
          _$SangeetLocalTrackObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)
        local,
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)
        full,
  }) {
    return local(id, name, externalUri, artists, album, durationMs, path);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)?
        full,
  }) {
    return local?.call(id, name, externalUri, artists, album, durationMs, path);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)?
        full,
    required TResult orElse(),
  }) {
    if (local != null) {
      return local(id, name, externalUri, artists, album, durationMs, path);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SangeetLocalTrackObject value) local,
    required TResult Function(SangeetFullTrackObject value) full,
  }) {
    return local(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SangeetLocalTrackObject value)? local,
    TResult? Function(SangeetFullTrackObject value)? full,
  }) {
    return local?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SangeetLocalTrackObject value)? local,
    TResult Function(SangeetFullTrackObject value)? full,
    required TResult orElse(),
  }) {
    if (local != null) {
      return local(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetLocalTrackObjectImplToJson(
      this,
    );
  }
}

abstract class SangeetLocalTrackObject implements SangeetTrackObject {
  factory SangeetLocalTrackObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      final List<SangeetSimpleArtistObject> artists,
      required final SangeetSimpleAlbumObject album,
      required final int durationMs,
      required final String path}) = _$SangeetLocalTrackObjectImpl;

  factory SangeetLocalTrackObject.fromJson(Map<String, dynamic> json) =
      _$SangeetLocalTrackObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SangeetSimpleArtistObject> get artists;
  @override
  SangeetSimpleAlbumObject get album;
  @override
  int get durationMs;
  String get path;

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetLocalTrackObjectImplCopyWith<_$SangeetLocalTrackObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SangeetFullTrackObjectImplCopyWith<$Res>
    implements $SangeetTrackObjectCopyWith<$Res> {
  factory _$$SangeetFullTrackObjectImplCopyWith(
          _$SangeetFullTrackObjectImpl value,
          $Res Function(_$SangeetFullTrackObjectImpl) then) =
      __$$SangeetFullTrackObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String externalUri,
      List<SangeetSimpleArtistObject> artists,
      SangeetSimpleAlbumObject album,
      int durationMs,
      String isrc,
      bool explicit,
      String status});

  @override
  $SangeetSimpleAlbumObjectCopyWith<$Res> get album;
}

/// @nodoc
class __$$SangeetFullTrackObjectImplCopyWithImpl<$Res>
    extends _$SangeetTrackObjectCopyWithImpl<$Res, _$SangeetFullTrackObjectImpl>
    implements _$$SangeetFullTrackObjectImplCopyWith<$Res> {
  __$$SangeetFullTrackObjectImplCopyWithImpl(
      _$SangeetFullTrackObjectImpl _value,
      $Res Function(_$SangeetFullTrackObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? externalUri = null,
    Object? artists = null,
    Object? album = null,
    Object? durationMs = null,
    Object? isrc = null,
    Object? explicit = null,
    Object? status = null,
  }) {
    return _then(_$SangeetFullTrackObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
      artists: null == artists
          ? _value._artists
          : artists // ignore: cast_nullable_to_non_nullable
              as List<SangeetSimpleArtistObject>,
      album: null == album
          ? _value.album
          : album // ignore: cast_nullable_to_non_nullable
              as SangeetSimpleAlbumObject,
      durationMs: null == durationMs
          ? _value.durationMs
          : durationMs // ignore: cast_nullable_to_non_nullable
              as int,
      isrc: null == isrc
          ? _value.isrc
          : isrc // ignore: cast_nullable_to_non_nullable
              as String,
      explicit: null == explicit
          ? _value.explicit
          : explicit // ignore: cast_nullable_to_non_nullable
              as bool,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetFullTrackObjectImpl implements SangeetFullTrackObject {
  _$SangeetFullTrackObjectImpl(
      {required this.id,
      required this.name,
      required this.externalUri,
      final List<SangeetSimpleArtistObject> artists = const [],
      required this.album,
      required this.durationMs,
      required this.isrc,
      required this.explicit,
      this.status = 'free',
      final String? $type})
      : _artists = artists,
        $type = $type ?? 'full';

  factory _$SangeetFullTrackObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetFullTrackObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String externalUri;
  final List<SangeetSimpleArtistObject> _artists;
  @override
  @JsonKey()
  List<SangeetSimpleArtistObject> get artists {
    if (_artists is EqualUnmodifiableListView) return _artists;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_artists);
  }

  @override
  final SangeetSimpleAlbumObject album;
  @override
  final int durationMs;
  @override
  final String isrc;
  @override
  final bool explicit;
  @override
  @JsonKey()
  final String status;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'SangeetTrackObject.full(id: $id, name: $name, externalUri: $externalUri, artists: $artists, album: $album, durationMs: $durationMs, isrc: $isrc, explicit: $explicit, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetFullTrackObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri) &&
            const DeepCollectionEquality().equals(other._artists, _artists) &&
            (identical(other.album, album) || other.album == album) &&
            (identical(other.durationMs, durationMs) ||
                other.durationMs == durationMs) &&
            (identical(other.isrc, isrc) || other.isrc == isrc) &&
            (identical(other.explicit, explicit) ||
                other.explicit == explicit) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      name,
      externalUri,
      const DeepCollectionEquality().hash(_artists),
      album,
      durationMs,
      isrc,
      explicit,
      status);

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetFullTrackObjectImplCopyWith<_$SangeetFullTrackObjectImpl>
      get copyWith => __$$SangeetFullTrackObjectImplCopyWithImpl<
          _$SangeetFullTrackObjectImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)
        local,
    required TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)
        full,
  }) {
    return full(id, name, externalUri, artists, album, durationMs, isrc,
        explicit, status);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult? Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)?
        full,
  }) {
    return full?.call(id, name, externalUri, artists, album, durationMs, isrc,
        explicit, status);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String path)?
        local,
    TResult Function(
            String id,
            String name,
            String externalUri,
            List<SangeetSimpleArtistObject> artists,
            SangeetSimpleAlbumObject album,
            int durationMs,
            String isrc,
            bool explicit,
            String status)?
        full,
    required TResult orElse(),
  }) {
    if (full != null) {
      return full(id, name, externalUri, artists, album, durationMs, isrc,
          explicit, status);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SangeetLocalTrackObject value) local,
    required TResult Function(SangeetFullTrackObject value) full,
  }) {
    return full(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SangeetLocalTrackObject value)? local,
    TResult? Function(SangeetFullTrackObject value)? full,
  }) {
    return full?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SangeetLocalTrackObject value)? local,
    TResult Function(SangeetFullTrackObject value)? full,
    required TResult orElse(),
  }) {
    if (full != null) {
      return full(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetFullTrackObjectImplToJson(
      this,
    );
  }
}

abstract class SangeetFullTrackObject implements SangeetTrackObject {
  factory SangeetFullTrackObject(
      {required final String id,
      required final String name,
      required final String externalUri,
      final List<SangeetSimpleArtistObject> artists,
      required final SangeetSimpleAlbumObject album,
      required final int durationMs,
      required final String isrc,
      required final bool explicit,
      final String status}) = _$SangeetFullTrackObjectImpl;

  factory SangeetFullTrackObject.fromJson(Map<String, dynamic> json) =
      _$SangeetFullTrackObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get externalUri;
  @override
  List<SangeetSimpleArtistObject> get artists;
  @override
  SangeetSimpleAlbumObject get album;
  @override
  int get durationMs;
  String get isrc;
  bool get explicit;
  String get status;

  /// Create a copy of SangeetTrackObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetFullTrackObjectImplCopyWith<_$SangeetFullTrackObjectImpl>
      get copyWith => throw _privateConstructorUsedError;
}

SangeetUserObject _$SangeetUserObjectFromJson(Map<String, dynamic> json) {
  return _SangeetUserObject.fromJson(json);
}

/// @nodoc
mixin _$SangeetUserObject {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  List<SangeetImageObject> get images => throw _privateConstructorUsedError;
  String get externalUri => throw _privateConstructorUsedError;

  /// Serializes this SangeetUserObject to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SangeetUserObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SangeetUserObjectCopyWith<SangeetUserObject> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SangeetUserObjectCopyWith<$Res> {
  factory $SangeetUserObjectCopyWith(
          SangeetUserObject value, $Res Function(SangeetUserObject) then) =
      _$SangeetUserObjectCopyWithImpl<$Res, SangeetUserObject>;
  @useResult
  $Res call(
      {String id,
      String name,
      List<SangeetImageObject> images,
      String externalUri});
}

/// @nodoc
class _$SangeetUserObjectCopyWithImpl<$Res, $Val extends SangeetUserObject>
    implements $SangeetUserObjectCopyWith<$Res> {
  _$SangeetUserObjectCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SangeetUserObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? images = null,
    Object? externalUri = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SangeetUserObjectImplCopyWith<$Res>
    implements $SangeetUserObjectCopyWith<$Res> {
  factory _$$SangeetUserObjectImplCopyWith(_$SangeetUserObjectImpl value,
          $Res Function(_$SangeetUserObjectImpl) then) =
      __$$SangeetUserObjectImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      List<SangeetImageObject> images,
      String externalUri});
}

/// @nodoc
class __$$SangeetUserObjectImplCopyWithImpl<$Res>
    extends _$SangeetUserObjectCopyWithImpl<$Res, _$SangeetUserObjectImpl>
    implements _$$SangeetUserObjectImplCopyWith<$Res> {
  __$$SangeetUserObjectImplCopyWithImpl(_$SangeetUserObjectImpl _value,
      $Res Function(_$SangeetUserObjectImpl) _then)
      : super(_value, _then);

  /// Create a copy of SangeetUserObject
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? images = null,
    Object? externalUri = null,
  }) {
    return _then(_$SangeetUserObjectImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      images: null == images
          ? _value._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<SangeetImageObject>,
      externalUri: null == externalUri
          ? _value.externalUri
          : externalUri // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SangeetUserObjectImpl implements _SangeetUserObject {
  _$SangeetUserObjectImpl(
      {required this.id,
      required this.name,
      final List<SangeetImageObject> images = const [],
      required this.externalUri})
      : _images = images;

  factory _$SangeetUserObjectImpl.fromJson(Map<String, dynamic> json) =>
      _$$SangeetUserObjectImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  final List<SangeetImageObject> _images;
  @override
  @JsonKey()
  List<SangeetImageObject> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final String externalUri;

  @override
  String toString() {
    return 'SangeetUserObject(id: $id, name: $name, images: $images, externalUri: $externalUri)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SangeetUserObjectImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.externalUri, externalUri) ||
                other.externalUri == externalUri));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name,
      const DeepCollectionEquality().hash(_images), externalUri);

  /// Create a copy of SangeetUserObject
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SangeetUserObjectImplCopyWith<_$SangeetUserObjectImpl> get copyWith =>
      __$$SangeetUserObjectImplCopyWithImpl<_$SangeetUserObjectImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SangeetUserObjectImplToJson(
      this,
    );
  }
}

abstract class _SangeetUserObject implements SangeetUserObject {
  factory _SangeetUserObject(
      {required final String id,
      required final String name,
      final List<SangeetImageObject> images,
      required final String externalUri}) = _$SangeetUserObjectImpl;

  factory _SangeetUserObject.fromJson(Map<String, dynamic> json) =
      _$SangeetUserObjectImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  List<SangeetImageObject> get images;
  @override
  String get externalUri;

  /// Create a copy of SangeetUserObject
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SangeetUserObjectImplCopyWith<_$SangeetUserObjectImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PluginConfiguration _$PluginConfigurationFromJson(Map<String, dynamic> json) {
  return _PluginConfiguration.fromJson(json);
}

/// @nodoc
mixin _$PluginConfiguration {
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String get author => throw _privateConstructorUsedError;
  String get entryPoint => throw _privateConstructorUsedError;
  String get pluginApiVersion => throw _privateConstructorUsedError;
  List<PluginApis> get apis => throw _privateConstructorUsedError;
  List<PluginAbilities> get abilities => throw _privateConstructorUsedError;
  String? get repository => throw _privateConstructorUsedError;

  /// Serializes this PluginConfiguration to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PluginConfigurationCopyWith<PluginConfiguration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PluginConfigurationCopyWith<$Res> {
  factory $PluginConfigurationCopyWith(
          PluginConfiguration value, $Res Function(PluginConfiguration) then) =
      _$PluginConfigurationCopyWithImpl<$Res, PluginConfiguration>;
  @useResult
  $Res call(
      {String name,
      String description,
      String version,
      String author,
      String entryPoint,
      String pluginApiVersion,
      List<PluginApis> apis,
      List<PluginAbilities> abilities,
      String? repository});
}

/// @nodoc
class _$PluginConfigurationCopyWithImpl<$Res, $Val extends PluginConfiguration>
    implements $PluginConfigurationCopyWith<$Res> {
  _$PluginConfigurationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? version = null,
    Object? author = null,
    Object? entryPoint = null,
    Object? pluginApiVersion = null,
    Object? apis = null,
    Object? abilities = null,
    Object? repository = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      entryPoint: null == entryPoint
          ? _value.entryPoint
          : entryPoint // ignore: cast_nullable_to_non_nullable
              as String,
      pluginApiVersion: null == pluginApiVersion
          ? _value.pluginApiVersion
          : pluginApiVersion // ignore: cast_nullable_to_non_nullable
              as String,
      apis: null == apis
          ? _value.apis
          : apis // ignore: cast_nullable_to_non_nullable
              as List<PluginApis>,
      abilities: null == abilities
          ? _value.abilities
          : abilities // ignore: cast_nullable_to_non_nullable
              as List<PluginAbilities>,
      repository: freezed == repository
          ? _value.repository
          : repository // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PluginConfigurationImplCopyWith<$Res>
    implements $PluginConfigurationCopyWith<$Res> {
  factory _$$PluginConfigurationImplCopyWith(_$PluginConfigurationImpl value,
          $Res Function(_$PluginConfigurationImpl) then) =
      __$$PluginConfigurationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String description,
      String version,
      String author,
      String entryPoint,
      String pluginApiVersion,
      List<PluginApis> apis,
      List<PluginAbilities> abilities,
      String? repository});
}

/// @nodoc
class __$$PluginConfigurationImplCopyWithImpl<$Res>
    extends _$PluginConfigurationCopyWithImpl<$Res, _$PluginConfigurationImpl>
    implements _$$PluginConfigurationImplCopyWith<$Res> {
  __$$PluginConfigurationImplCopyWithImpl(_$PluginConfigurationImpl _value,
      $Res Function(_$PluginConfigurationImpl) _then)
      : super(_value, _then);

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? version = null,
    Object? author = null,
    Object? entryPoint = null,
    Object? pluginApiVersion = null,
    Object? apis = null,
    Object? abilities = null,
    Object? repository = freezed,
  }) {
    return _then(_$PluginConfigurationImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      author: null == author
          ? _value.author
          : author // ignore: cast_nullable_to_non_nullable
              as String,
      entryPoint: null == entryPoint
          ? _value.entryPoint
          : entryPoint // ignore: cast_nullable_to_non_nullable
              as String,
      pluginApiVersion: null == pluginApiVersion
          ? _value.pluginApiVersion
          : pluginApiVersion // ignore: cast_nullable_to_non_nullable
              as String,
      apis: null == apis
          ? _value._apis
          : apis // ignore: cast_nullable_to_non_nullable
              as List<PluginApis>,
      abilities: null == abilities
          ? _value._abilities
          : abilities // ignore: cast_nullable_to_non_nullable
              as List<PluginAbilities>,
      repository: freezed == repository
          ? _value.repository
          : repository // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PluginConfigurationImpl extends _PluginConfiguration {
  _$PluginConfigurationImpl(
      {required this.name,
      required this.description,
      required this.version,
      required this.author,
      required this.entryPoint,
      required this.pluginApiVersion,
      final List<PluginApis> apis = const [],
      final List<PluginAbilities> abilities = const [],
      this.repository})
      : _apis = apis,
        _abilities = abilities,
        super._();

  factory _$PluginConfigurationImpl.fromJson(Map<String, dynamic> json) =>
      _$$PluginConfigurationImplFromJson(json);

  @override
  final String name;
  @override
  final String description;
  @override
  final String version;
  @override
  final String author;
  @override
  final String entryPoint;
  @override
  final String pluginApiVersion;
  final List<PluginApis> _apis;
  @override
  @JsonKey()
  List<PluginApis> get apis {
    if (_apis is EqualUnmodifiableListView) return _apis;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_apis);
  }

  final List<PluginAbilities> _abilities;
  @override
  @JsonKey()
  List<PluginAbilities> get abilities {
    if (_abilities is EqualUnmodifiableListView) return _abilities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_abilities);
  }

  @override
  final String? repository;

  @override
  String toString() {
    return 'PluginConfiguration(name: $name, description: $description, version: $version, author: $author, entryPoint: $entryPoint, pluginApiVersion: $pluginApiVersion, apis: $apis, abilities: $abilities, repository: $repository)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PluginConfigurationImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.author, author) || other.author == author) &&
            (identical(other.entryPoint, entryPoint) ||
                other.entryPoint == entryPoint) &&
            (identical(other.pluginApiVersion, pluginApiVersion) ||
                other.pluginApiVersion == pluginApiVersion) &&
            const DeepCollectionEquality().equals(other._apis, _apis) &&
            const DeepCollectionEquality()
                .equals(other._abilities, _abilities) &&
            (identical(other.repository, repository) ||
                other.repository == repository));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      description,
      version,
      author,
      entryPoint,
      pluginApiVersion,
      const DeepCollectionEquality().hash(_apis),
      const DeepCollectionEquality().hash(_abilities),
      repository);

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PluginConfigurationImplCopyWith<_$PluginConfigurationImpl> get copyWith =>
      __$$PluginConfigurationImplCopyWithImpl<_$PluginConfigurationImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PluginConfigurationImplToJson(
      this,
    );
  }
}

abstract class _PluginConfiguration extends PluginConfiguration {
  factory _PluginConfiguration(
      {required final String name,
      required final String description,
      required final String version,
      required final String author,
      required final String entryPoint,
      required final String pluginApiVersion,
      final List<PluginApis> apis,
      final List<PluginAbilities> abilities,
      final String? repository}) = _$PluginConfigurationImpl;
  _PluginConfiguration._() : super._();

  factory _PluginConfiguration.fromJson(Map<String, dynamic> json) =
      _$PluginConfigurationImpl.fromJson;

  @override
  String get name;
  @override
  String get description;
  @override
  String get version;
  @override
  String get author;
  @override
  String get entryPoint;
  @override
  String get pluginApiVersion;
  @override
  List<PluginApis> get apis;
  @override
  List<PluginAbilities> get abilities;
  @override
  String? get repository;

  /// Create a copy of PluginConfiguration
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PluginConfigurationImplCopyWith<_$PluginConfigurationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

PluginUpdateAvailable _$PluginUpdateAvailableFromJson(
    Map<String, dynamic> json) {
  return _PluginUpdateAvailable.fromJson(json);
}

/// @nodoc
mixin _$PluginUpdateAvailable {
  String get downloadUrl => throw _privateConstructorUsedError;
  String get version => throw _privateConstructorUsedError;
  String? get changelog => throw _privateConstructorUsedError;

  /// Serializes this PluginUpdateAvailable to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PluginUpdateAvailableCopyWith<PluginUpdateAvailable> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PluginUpdateAvailableCopyWith<$Res> {
  factory $PluginUpdateAvailableCopyWith(PluginUpdateAvailable value,
          $Res Function(PluginUpdateAvailable) then) =
      _$PluginUpdateAvailableCopyWithImpl<$Res, PluginUpdateAvailable>;
  @useResult
  $Res call({String downloadUrl, String version, String? changelog});
}

/// @nodoc
class _$PluginUpdateAvailableCopyWithImpl<$Res,
        $Val extends PluginUpdateAvailable>
    implements $PluginUpdateAvailableCopyWith<$Res> {
  _$PluginUpdateAvailableCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadUrl = null,
    Object? version = null,
    Object? changelog = freezed,
  }) {
    return _then(_value.copyWith(
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      changelog: freezed == changelog
          ? _value.changelog
          : changelog // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PluginUpdateAvailableImplCopyWith<$Res>
    implements $PluginUpdateAvailableCopyWith<$Res> {
  factory _$$PluginUpdateAvailableImplCopyWith(
          _$PluginUpdateAvailableImpl value,
          $Res Function(_$PluginUpdateAvailableImpl) then) =
      __$$PluginUpdateAvailableImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String downloadUrl, String version, String? changelog});
}

/// @nodoc
class __$$PluginUpdateAvailableImplCopyWithImpl<$Res>
    extends _$PluginUpdateAvailableCopyWithImpl<$Res,
        _$PluginUpdateAvailableImpl>
    implements _$$PluginUpdateAvailableImplCopyWith<$Res> {
  __$$PluginUpdateAvailableImplCopyWithImpl(_$PluginUpdateAvailableImpl _value,
      $Res Function(_$PluginUpdateAvailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? downloadUrl = null,
    Object? version = null,
    Object? changelog = freezed,
  }) {
    return _then(_$PluginUpdateAvailableImpl(
      downloadUrl: null == downloadUrl
          ? _value.downloadUrl
          : downloadUrl // ignore: cast_nullable_to_non_nullable
              as String,
      version: null == version
          ? _value.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
      changelog: freezed == changelog
          ? _value.changelog
          : changelog // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PluginUpdateAvailableImpl implements _PluginUpdateAvailable {
  _$PluginUpdateAvailableImpl(
      {required this.downloadUrl, required this.version, this.changelog});

  factory _$PluginUpdateAvailableImpl.fromJson(Map<String, dynamic> json) =>
      _$$PluginUpdateAvailableImplFromJson(json);

  @override
  final String downloadUrl;
  @override
  final String version;
  @override
  final String? changelog;

  @override
  String toString() {
    return 'PluginUpdateAvailable(downloadUrl: $downloadUrl, version: $version, changelog: $changelog)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PluginUpdateAvailableImpl &&
            (identical(other.downloadUrl, downloadUrl) ||
                other.downloadUrl == downloadUrl) &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.changelog, changelog) ||
                other.changelog == changelog));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, downloadUrl, version, changelog);

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PluginUpdateAvailableImplCopyWith<_$PluginUpdateAvailableImpl>
      get copyWith => __$$PluginUpdateAvailableImplCopyWithImpl<
          _$PluginUpdateAvailableImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PluginUpdateAvailableImplToJson(
      this,
    );
  }
}

abstract class _PluginUpdateAvailable implements PluginUpdateAvailable {
  factory _PluginUpdateAvailable(
      {required final String downloadUrl,
      required final String version,
      final String? changelog}) = _$PluginUpdateAvailableImpl;

  factory _PluginUpdateAvailable.fromJson(Map<String, dynamic> json) =
      _$PluginUpdateAvailableImpl.fromJson;

  @override
  String get downloadUrl;
  @override
  String get version;
  @override
  String? get changelog;

  /// Create a copy of PluginUpdateAvailable
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PluginUpdateAvailableImplCopyWith<_$PluginUpdateAvailableImpl>
      get copyWith => throw _privateConstructorUsedError;
}

MetadataPluginRepository _$MetadataPluginRepositoryFromJson(
    Map<String, dynamic> json) {
  return _MetadataPluginRepository.fromJson(json);
}

/// @nodoc
mixin _$MetadataPluginRepository {
  String get name => throw _privateConstructorUsedError;
  String get owner => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  String get repoUrl => throw _privateConstructorUsedError;
  List<String> get topics => throw _privateConstructorUsedError;

  /// Serializes this MetadataPluginRepository to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MetadataPluginRepositoryCopyWith<MetadataPluginRepository> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MetadataPluginRepositoryCopyWith<$Res> {
  factory $MetadataPluginRepositoryCopyWith(MetadataPluginRepository value,
          $Res Function(MetadataPluginRepository) then) =
      _$MetadataPluginRepositoryCopyWithImpl<$Res, MetadataPluginRepository>;
  @useResult
  $Res call(
      {String name,
      String owner,
      String description,
      String repoUrl,
      List<String> topics});
}

/// @nodoc
class _$MetadataPluginRepositoryCopyWithImpl<$Res,
        $Val extends MetadataPluginRepository>
    implements $MetadataPluginRepositoryCopyWith<$Res> {
  _$MetadataPluginRepositoryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? owner = null,
    Object? description = null,
    Object? repoUrl = null,
    Object? topics = null,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      repoUrl: null == repoUrl
          ? _value.repoUrl
          : repoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      topics: null == topics
          ? _value.topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MetadataPluginRepositoryImplCopyWith<$Res>
    implements $MetadataPluginRepositoryCopyWith<$Res> {
  factory _$$MetadataPluginRepositoryImplCopyWith(
          _$MetadataPluginRepositoryImpl value,
          $Res Function(_$MetadataPluginRepositoryImpl) then) =
      __$$MetadataPluginRepositoryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String owner,
      String description,
      String repoUrl,
      List<String> topics});
}

/// @nodoc
class __$$MetadataPluginRepositoryImplCopyWithImpl<$Res>
    extends _$MetadataPluginRepositoryCopyWithImpl<$Res,
        _$MetadataPluginRepositoryImpl>
    implements _$$MetadataPluginRepositoryImplCopyWith<$Res> {
  __$$MetadataPluginRepositoryImplCopyWithImpl(
      _$MetadataPluginRepositoryImpl _value,
      $Res Function(_$MetadataPluginRepositoryImpl) _then)
      : super(_value, _then);

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? owner = null,
    Object? description = null,
    Object? repoUrl = null,
    Object? topics = null,
  }) {
    return _then(_$MetadataPluginRepositoryImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      owner: null == owner
          ? _value.owner
          : owner // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      repoUrl: null == repoUrl
          ? _value.repoUrl
          : repoUrl // ignore: cast_nullable_to_non_nullable
              as String,
      topics: null == topics
          ? _value._topics
          : topics // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MetadataPluginRepositoryImpl implements _MetadataPluginRepository {
  _$MetadataPluginRepositoryImpl(
      {required this.name,
      required this.owner,
      required this.description,
      required this.repoUrl,
      required final List<String> topics})
      : _topics = topics;

  factory _$MetadataPluginRepositoryImpl.fromJson(Map<String, dynamic> json) =>
      _$$MetadataPluginRepositoryImplFromJson(json);

  @override
  final String name;
  @override
  final String owner;
  @override
  final String description;
  @override
  final String repoUrl;
  final List<String> _topics;
  @override
  List<String> get topics {
    if (_topics is EqualUnmodifiableListView) return _topics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topics);
  }

  @override
  String toString() {
    return 'MetadataPluginRepository(name: $name, owner: $owner, description: $description, repoUrl: $repoUrl, topics: $topics)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MetadataPluginRepositoryImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.owner, owner) || other.owner == owner) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.repoUrl, repoUrl) || other.repoUrl == repoUrl) &&
            const DeepCollectionEquality().equals(other._topics, _topics));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, name, owner, description,
      repoUrl, const DeepCollectionEquality().hash(_topics));

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MetadataPluginRepositoryImplCopyWith<_$MetadataPluginRepositoryImpl>
      get copyWith => __$$MetadataPluginRepositoryImplCopyWithImpl<
          _$MetadataPluginRepositoryImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MetadataPluginRepositoryImplToJson(
      this,
    );
  }
}

abstract class _MetadataPluginRepository implements MetadataPluginRepository {
  factory _MetadataPluginRepository(
      {required final String name,
      required final String owner,
      required final String description,
      required final String repoUrl,
      required final List<String> topics}) = _$MetadataPluginRepositoryImpl;

  factory _MetadataPluginRepository.fromJson(Map<String, dynamic> json) =
      _$MetadataPluginRepositoryImpl.fromJson;

  @override
  String get name;
  @override
  String get owner;
  @override
  String get description;
  @override
  String get repoUrl;
  @override
  List<String> get topics;

  /// Create a copy of MetadataPluginRepository
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MetadataPluginRepositoryImplCopyWith<_$MetadataPluginRepositoryImpl>
      get copyWith => throw _privateConstructorUsedError;
}
