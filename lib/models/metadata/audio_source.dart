part of 'metadata.dart';

final oneOptionalDecimalFormatter = NumberFormat('0.#', 'en_US');

enum SangeetMediaCompressionType {
  lossy,
  lossless,
}

@Freezed(unionKey: 'type')
class SangeetAudioSourceContainerPreset
    with _$SangeetAudioSourceContainerPreset {
  const SangeetAudioSourceContainerPreset._();

  @FreezedUnionValue("lossy")
  factory SangeetAudioSourceContainerPreset.lossy({
    required SangeetMediaCompressionType type,
    required String name,
    required List<SangeetAudioLossyContainerQuality> qualities,
  }) = SangeetAudioSourceContainerPresetLossy;

  @FreezedUnionValue("lossless")
  factory SangeetAudioSourceContainerPreset.lossless({
    required SangeetMediaCompressionType type,
    required String name,
    required List<SangeetAudioLosslessContainerQuality> qualities,
  }) = SangeetAudioSourceContainerPresetLossless;

  factory SangeetAudioSourceContainerPreset.fromJson(
          Map<String, dynamic> json) =>
      _$SangeetAudioSourceContainerPresetFromJson(json);

  String getFileExtension() {
    return switch (name) {
      "mp4" => "m4a",
      "webm" => "weba",
      _ => name,
    };
  }
}

@freezed
class SangeetAudioLossyContainerQuality
    with _$SangeetAudioLossyContainerQuality {
  const SangeetAudioLossyContainerQuality._();

  factory SangeetAudioLossyContainerQuality({
    required int bitrate, // bits per second
  }) = _SangeetAudioLossyContainerQuality;

  factory SangeetAudioLossyContainerQuality.fromJson(
          Map<String, dynamic> json) =>
      _$SangeetAudioLossyContainerQualityFromJson(json);

  @override
  toString() {
    return "${oneOptionalDecimalFormatter.format(bitrate / 1000)}kbps";
  }
}

@freezed
class SangeetAudioLosslessContainerQuality
    with _$SangeetAudioLosslessContainerQuality {
  const SangeetAudioLosslessContainerQuality._();

  factory SangeetAudioLosslessContainerQuality({
    required int bitDepth, // bit
    required int sampleRate, // hz
  }) = _SangeetAudioLosslessContainerQuality;

  factory SangeetAudioLosslessContainerQuality.fromJson(
          Map<String, dynamic> json) =>
      _$SangeetAudioLosslessContainerQualityFromJson(json);

  @override
  toString() {
    return "${bitDepth}bit • ${oneOptionalDecimalFormatter.format(sampleRate / 1000)}kHz";
  }
}

@freezed
class SangeetAudioSourceMatchObject with _$SangeetAudioSourceMatchObject {
  factory SangeetAudioSourceMatchObject({
    required String id,
    required String title,
    required List<String> artists,
    required Duration duration,
    String? thumbnail,
    required String externalUri,
  }) = _SangeetAudioSourceMatchObject;

  factory SangeetAudioSourceMatchObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetAudioSourceMatchObjectFromJson(json);
}

@freezed
class SangeetAudioSourceStreamObject with _$SangeetAudioSourceStreamObject {
  factory SangeetAudioSourceStreamObject({
    required String url,
    required String container,
    required SangeetMediaCompressionType type,
    String? codec,
    double? bitrate,
    int? bitDepth,
    double? sampleRate,
  }) = _SangeetAudioSourceStreamObject;

  factory SangeetAudioSourceStreamObject.fromJson(Map<String, dynamic> json) =>
      _$SangeetAudioSourceStreamObjectFromJson(json);
}
