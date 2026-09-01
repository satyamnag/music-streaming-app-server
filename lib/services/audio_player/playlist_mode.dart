/// Loop modes for the playback engine.
///
/// Mirrors the media_kit `PlaylistMode` shape so existing consumers (loop
/// toggles, repeating modes) keep working after media_kit is removed.
enum PlaylistMode {
  /// End playback once end of the playlist is reached.
  none,

  /// Indefinitely loop over the currently playing file in the playlist.
  single,

  /// Loop over the playlist & restart it from beginning once end is reached.
  loop,
}
