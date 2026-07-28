part of 'metadata.dart';

@Freezed(genericArgumentFactories: true)
class SangeetPaginationResponseObject<T>
    with _$SangeetPaginationResponseObject<T> {
  factory SangeetPaginationResponseObject({
    required int limit,
    required int? nextOffset,
    required int total,
    required bool hasMore,
    required List<T> items,
  }) = _SangeetPaginationResponseObject<T>;

  factory SangeetPaginationResponseObject.fromJson(
    Map<String, Object?> json,
    T Function(Map<String, dynamic> json) fromJsonT,
  ) =>
      _$SangeetPaginationResponseObjectFromJson<T>(
        json,
        (json) => fromJsonT(json as Map<String, dynamic>),
      );
}
