part of 'metadata.dart';

@freezed
class SangeetUserObject with _$SangeetUserObject {
  factory SangeetUserObject({
    required final String id,
    required final String name,
    @Default([]) final List<SangeetImageObject> images,
    required final String externalUri,
  }) = _SangeetUserObject;

  factory SangeetUserObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetUserObjectFromJson(json);
}
