// Guards the share message: a recipient who does NOT have the app must get
// something they can act on.
//
// ## The bug this replaces
// The existing share action sent ONLY the track's name:
//
//     SharePlus.instance.share(ShareParams(text: shareText))   // just "Song Name"
//
// A recipient received the words "Niluvadu Manasu" and nothing to tap. The share
// could not lead anyone to the song, or to the app.
//
// The message now carries the Play Store listing - the only link that works for
// someone without the app - plus a custom-scheme deep link that opens the track
// directly for someone who already has it. Both audiences are covered, which is
// what these tests pin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/share/track_share.dart';

SangeetTrackObject track({
  String id = 'abc-123',
  String name = 'Niluvadu Manasu',
  List<String> artists = const ['S. P. Balasubrahmanyam'],
}) {
  return SangeetTrackObject.full(
    id: id,
    name: name,
    externalUri: '',
    artists: artists
        .map((a) => SangeetSimpleArtistObject(
              id: a,
              name: a,
              externalUri: '',
            ))
        .toList(),
    album: SangeetSimpleAlbumObject(
      id: 'a1',
      name: 'Album',
      externalUri: '',
      artists: const <SangeetSimpleArtistObject>[],
      albumType: SangeetAlbumType.album,
    ),
    durationMs: 1000,
    isrc: '',
    explicit: false,
  );
}

void main() {
  group('the share message is actionable without the app', () {
    test('it contains the Play Store listing', () {
      final message = TrackShare.messageFor(track());

      expect(
        message.contains('play.google.com/store/apps/details'),
        isTrue,
        reason: 'a recipient with no app needs a link that opens something; a '
            'custom scheme alone does nothing on their phone',
      );
      expect(
        message.contains(TrackShare.playStorePackageId),
        isTrue,
        reason: 'the listing must point at THIS app',
      );
    });

    test('the package id matches the Android applicationId', () {
      // A share link to the wrong package would send listeners to a 404 or,
      // worse, to someone else's app.
      final gradle = _read('android/app/build.gradle');
      expect(
        gradle.contains('applicationId "${TrackShare.playStorePackageId}"'),
        isTrue,
        reason: 'TrackShare.playStorePackageId must equal the applicationId, or '
            'the shared link does not resolve to this app',
      );
    });

    test('it names the track', () {
      final message = TrackShare.messageFor(track());
      expect(message.contains('Niluvadu Manasu'), isTrue,
          reason: 'the message must say what is being shared');
    });

    test('it names the artist when one is known', () {
      final message = TrackShare.messageFor(track());
      expect(message.contains('S. P. Balasubrahmanyam'), isTrue);
    });

    test('it mentions the app by name', () {
      expect(TrackShare.messageFor(track()).contains('Soulful Bhakti'), isTrue);
    });
  });

  group('the deep link opens the track itself', () {
    test('it uses the declared sangeet scheme and carries the track id', () {
      final link = TrackShare.deepLinkFor(track(id: 'track-xyz'));
      expect(link.startsWith('sangeet://'), isTrue,
          reason: 'the scheme must be the one AndroidManifest declares');
      expect(link.contains('track-xyz'), isTrue,
          reason: 'without the id the app can only open its home screen');
    });

    test('the manifest still declares that scheme', () {
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(
        manifest.contains('android:scheme="sangeet"'),
        isTrue,
        reason: 'the deep link is inert unless the manifest handles the scheme',
      );
    });

    test('an id needing escaping is encoded, not injected', () {
      final link = TrackShare.deepLinkFor(track(id: 'a/b c?d'));
      expect(link.contains('a%2Fb%20c%3Fd'), isTrue,
          reason: 'an unescaped id could break the URI or add query parameters');
    });
  });

  group('degenerate tracks do not produce a broken message', () {
    test('a blank name still yields a usable message', () {
      final message = TrackShare.messageFor(track(name: '   '));
      expect(message.contains('this track'), isTrue);
      expect(message.contains(TrackShare.playStoreUrl), isTrue,
          reason: 'the link must survive even with no title');
    });

    test('a track with no artists omits the dash rather than leaving one', () {
      final message = TrackShare.messageFor(track(artists: const []));
      expect(message.contains(' — '), isFalse,
          reason: 'an em dash with nothing after it reads as a broken message');
    });

    test('the first line identifies the song, since previews show only that',
        () {
      final message = TrackShare.messageFor(track());
      final firstLine = message.split('\n').first;
      expect(firstLine.contains('Niluvadu Manasu'), isTrue,
          reason: 'WhatsApp and similar show only the first line in the '
              'preview, so the song must be named there');
    });
  });
}

String _read(String path) => File(path).readAsStringSync();
