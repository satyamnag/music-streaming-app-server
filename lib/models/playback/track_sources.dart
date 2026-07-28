import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sangeet/models/metadata/metadata.dart';

part 'track_sources.g.dart';

@JsonSerializable()
class BasicSourcedTrack {
  final SangeetFullTrackObject query;
  final SangeetAudioSourceMatchObject info;
  final String source;
  final List<SangeetAudioSourceStreamObject> sources;
  final List<SangeetAudioSourceMatchObject> siblings;
  BasicSourcedTrack({
    required this.query,
    required this.source,
    required this.info,
    required this.sources,
    this.siblings = const [],
  });

  factory BasicSourcedTrack.fromJson(Map<String, dynamic> json) =>
      _$BasicSourcedTrackFromJson(json);
  Map<String, dynamic> toJson() => _$BasicSourcedTrackToJson(this);
}
