part of 'metadata.dart';

@Freezed(genericArgumentFactories: true)
class SangeetBrowseSectionObject<T> with _$SangeetBrowseSectionObject<T> {
  factory SangeetBrowseSectionObject({
    required String id,
    required String title,
    required String externalUri,
    required bool browseMore,
    required List<T> items,
  }) = _SangeetBrowseSectionObject<T>;

  factory SangeetBrowseSectionObject.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) =>
      _$SangeetBrowseSectionObjectFromJson<T>(
        json,
        (json) => fromJsonT(json as Map<String, dynamic>),
      );
}
