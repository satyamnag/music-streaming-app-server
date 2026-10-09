import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';
import 'package:sangeet/models/metadata/metadata.dart';

/// Builds and sends the share text for a track.
///
/// ## Why a dedicated helper
/// The existing share action sent **only the track's name** - no link, no
/// mention of the app. A recipient got "Niluvadu Manasu" with nothing to tap, so
/// the share could not actually lead anyone to the song or to the app. That is
/// the behaviour this replaces.
///
/// ## What the message has to do
/// Two things, in this order of importance:
///
///  1. **Be actionable by someone who does NOT have the app.** A custom-scheme
///     link (`sangeet://...`) is useless to them: nothing handles it, so the tap
///     does nothing at all. The message must therefore carry a link that works on
///     a phone without the app, which means the Play Store listing.
///  2. **Name the song and the app**, so the message reads as a recommendation
///     rather than as a bare URL.
///
/// A custom-scheme link IS included as well, because it is the only way to open
/// the track directly for a recipient who already has the app - Android gives
/// the app that link when present and otherwise leaves the https link. Both are
/// sent so neither audience is stranded.
class TrackShare {
  const TrackShare._();

  /// The app's Play Store id, matching `applicationId` in
  /// `android/app/build.gradle`. Used for the install link, so a recipient
  /// without the app lands on the listing rather than on a dead scheme.
  static const String playStorePackageId = 'com.soulfulbhakti.app';

  /// Play Store listing URL for this app.
  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$playStorePackageId';

  /// Deep link that opens [track] directly when the app is installed.
  ///
  /// Uses the `sangeet` scheme declared in `AndroidManifest.xml`. It carries the
  /// track id, so the app can route to the song rather than only to the home
  /// screen.
  static String deepLinkFor(SangeetTrackObject track) =>
      'sangeet://track/${Uri.encodeComponent(track.id)}';

  /// The message body shared for [track].
  ///
  /// Kept free of any trailing punctuation that a messaging app might mangle,
  /// and written so the first line alone still says what the song is - the
  /// preview in WhatsApp and similar shows only the first line.
  static String messageFor(SangeetTrackObject track) {
    final title = track.name.trim().isEmpty ? 'this track' : track.name.trim();
    final artist = track.artists
        .map((a) => a.name.trim())
        .where((n) => n.isNotEmpty)
        .join(', ');

    final buffer = StringBuffer()
      ..writeln('🎵 $title${artist.isEmpty ? '' : ' — $artist'}')
      ..writeln()
      ..writeln('Listen on Soulful Bhakti:')
      // The https listing first: it is the link that works for everyone. The
      // scheme is on the next line so a recipient WITH the app still gets a
      // one-tap route to the track.
      ..writeln(playStoreUrl)
      ..write(deepLinkFor(track));

    return buffer.toString();
  }

  /// Shares [track] through the platform share sheet.
  ///
  /// [sharePositionOrigin] is required on iPad, where the sheet is presented as
  /// a popover and UIKit needs a rectangle to anchor it to; without one the call
  /// throws on that platform. It is optional so phone callers can omit it.
  static Future<void> shareTrack(
    SangeetTrackObject track, {
    Rect? sharePositionOrigin,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        text: messageFor(track),
        subject: track.name.trim().isEmpty
            ? 'Listen on Soulful Bhakti'
            : '${track.name.trim()} on Soulful Bhakti',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
