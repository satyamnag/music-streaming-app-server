import 'package:sangeet/models/metadata/metadata.dart';

class TrackNotFoundError extends Error {
  final SangeetTrackObject track;

  TrackNotFoundError(this.track);

  @override
  String toString() {
    return '[TrackNotFoundError] ${track.name} - ${track.artists.join(", ")}';
  }
}
