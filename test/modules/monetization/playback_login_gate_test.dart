// Guards the "sign in before listening" rule.
//
// The requirement: a user must sign in before ANY track can be listened to —
// free track and paid track alike. Three things have to stay true for that to
// hold, and each is checked here:
//
//  1. THE RULE — `isPlaybackUnlocked` is the whole decision, so it is tested
//     directly as a pure function.
//
//  2. THE BOUNDARY — every audio byte the in-app player receives is served by
//     the local stream proxy (`SangeetMedia.uri` builds
//     `http://<host>:<port>/stream/<trackId>`), so a signed-out request must be
//     refused with 401 there. That is what makes the rule hold for queue
//     restore, next/previous, auto-advance, the endless-playback append and
//     remote control — paths that never touch a UI gate.
//
//  3. THE GATES — the shared track/album gates must ask for sign-in *before*
//     they consider the paywall (a signed-out user cannot buy anything), and the
//     player notifier must refuse to start or jump to a queue without a session
//     and must stop playing when the user signs out.
//
// Points 2 and 3 read the source, exactly like `test/album_no_play_icon_test.dart`:
// exercising them for real needs an audio engine, a platform channel and a
// network. A probe fails the moment the enforcement is deleted, which is the
// regression worth guarding.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/monetization/premium_access.dart';

/// The text of a single `static` member of `PremiumAccess`, from its signature
/// up to the next `static` member. Members in that file are two-space indented,
/// so the next sibling is the next line starting with `  static `.
String _member(String source, String signature) {
  final start = source.indexOf(signature);
  if (start == -1) return '';
  final next = source.indexOf('\n  static ', start + signature.length);
  return source.substring(start, next == -1 ? source.length : next);
}

int _count(String source, RegExp pattern) =>
    pattern.allMatches(source).length;

void main() {
  group('the rule: playback needs a signed-in user where sign-in exists', () {
    test('a signed-out user cannot listen when sign-in is required', () {
      expect(
        isPlaybackUnlocked(signInRequiredOnPlatform: true, signedIn: false),
        isFalse,
        reason: 'this is the whole requirement: no session, no playback',
      );
    });

    test('a signed-in user may listen', () {
      expect(
        isPlaybackUnlocked(signInRequiredOnPlatform: true, signedIn: true),
        isTrue,
      );
    });

    test('without a sign-in bridge playback is not blocked', () {
      // Desktop/macOS/Linux/iOS have no Clerk bridge, so requiring a login there
      // would silence the app rather than gate it.
      expect(
        isPlaybackUnlocked(signInRequiredOnPlatform: false, signedIn: false),
        isTrue,
      );
      expect(
        isPlaybackUnlocked(signInRequiredOnPlatform: false, signedIn: true),
        isTrue,
      );
    });

    test('the rule is applied to the platform the app ships for', () {
      // The sign-in bridge is Android-only (ClerkBridge registered by
      // MainActivity), and that is what the requirement is about.
      expect(
        File(
          'android/app/src/main/kotlin/com/sangeet/app/ClerkBridge.kt',
        ).existsSync(),
        isTrue,
        reason: 'the Android sign-in bridge must still exist — it is what '
            'loginRequiredForPlayback is scoped to',
      );
      final mainActivity = File(
        'android/app/src/main/kotlin/com/sangeet/app/MainActivity.kt',
      ).readAsStringSync();
      expect(mainActivity.contains('ClerkBridge('), isTrue);
    });
  });

  group('the boundary: the local stream proxy refuses signed-out requests', () {
    final playback =
        File('lib/provider/server/routes/playback.dart').readAsStringSync();

    test('both HEAD and GET /stream/<trackId> are gated', () {
      expect(
        _count(playback, RegExp(r'PremiumAccess\.isPlaybackAllowed\(ref\)')),
        greaterThanOrEqualTo(2),
        reason: 'headStreamTrackId AND getStreamTrackId must each check the '
            'session: the player issues HEAD before every GET, and either one '
            'being ungated leaves a way to stream without signing in',
      );
    });

    test('a rejected request is 401, not 200 with an empty body', () {
      expect(
        _count(playback, RegExp(r'Response\(\s*401')),
        greaterThanOrEqualTo(2),
        reason: '401 Unauthorized is the correct signal for "no session"; '
            'anything else and the client cannot tell this from a broken track',
      );
    });

    test('the session check runs before the paid check', () {
      for (final signature in const [
        'Future<Response> headStreamTrackId(',
        'Future<Response> getStreamTrackId(',
      ]) {
        final start = playback.indexOf(signature);
        expect(start, greaterThan(-1), reason: '$signature must exist');
        // The handler ends at the next handler's doc comment.
        final end = playback.indexOf('/// @', start);
        final body =
            playback.substring(start, end == -1 ? playback.length : end);
        final session = body.indexOf('isPlaybackAllowed');
        final paid = body.indexOf("status == 'paid'");
        expect(session, greaterThan(-1), reason: '$signature must gate the session');
        expect(paid, greaterThan(-1));
        expect(
          session,
          lessThan(paid),
          reason: 'in $signature the sign-in check must come before the premium '
              'check: a signed-out user is not a free user to be shown a paywall',
        );
      }
    });

    test('the other local endpoint that hands out audio is gated too', () {
      final supabaseData =
          File('lib/provider/server/routes/supabase_data.dart')
              .readAsStringSync();
      expect(
        supabaseData.contains('PremiumAccess.isPlaybackAllowed(ref)'),
        isTrue,
        reason: 'GET /supabase/stream/<id> returns a playable URL; leaving it '
            'ungated would be a second way to listen without signing in',
      );
    });
  });

  group('the gates: sign-in comes before the paywall', () {
    final premium =
        File('lib/modules/monetization/premium_access.dart').readAsStringSync();

    test('isPlaybackAllowed is the platform rule plus the session', () {
      final body = _member(premium, 'static bool isPlaybackAllowed(');
      expect(body, contains('signInRequiredOnPlatform: loginRequiredForPlayback'));
      expect(body, contains('signedIn: isSignedIn(ref)'));
    });

    test('the gate reads the synchronous auth mirror, not the provider', () {
      // Reading `clerkAuthProvider` from a provider's Ref answered
      // "signed out" for a signed-in user (measured on a device: playback was
      // refused and the stream endpoint 401'd), so the gate must read the
      // mirror ClerkAuthNotifier keeps.
      final body = _member(premium, 'static bool isSignedIn(');
      expect(body, isNotEmpty);
      expect(body, contains('ClerkAuthSignal.current.signedIn'));
      expect(
        body.contains('ref.read('),
        isFalse,
        reason: 'the gate must not read the async provider synchronously',
      );
    });

    test('the notifier keeps the mirror up to date', () {
      final source =
          File('lib/provider/auth/clerk_auth_provider.dart').readAsStringSync();
      expect(source, contains('class ClerkAuthSignal'));
      // Both places the notifier resolves a state: the event stream and the
      // initial getState.
      expect(
        RegExp(r'ClerkAuthSignal\.update\(').allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('the album gate asks for sign-in first', () {
      final body = _member(premium, 'static Future<bool> _gate({');
      expect(body, isNotEmpty);
      final signIn = body.indexOf('requireSignInToPlay');
      final premiumCheck = body.indexOf('isPremiumUser(ref)');
      expect(signIn, greaterThan(-1));
      expect(premiumCheck, greaterThan(-1));
      expect(
        signIn,
        lessThan(premiumCheck),
        reason: 'the sign-in gate must run before the premium check, otherwise '
            'a signed-out user is offered a purchase they cannot complete',
      );
    });

    test('the track gate asks for sign-in first, for FREE tracks too', () {
      final body = _member(premium, 'static Future<bool> gateTrackPlay({');
      expect(body, isNotEmpty);
      final signIn = body.indexOf('requireSignInToPlay');
      final premiumCheck = body.indexOf('isPremiumUser(ref)');
      expect(signIn, greaterThan(-1),
          reason: 'gateTrackPlay must require a session — this is the path every '
              'track row and every home card uses');
      expect(premiumCheck, greaterThan(-1));
      expect(signIn, lessThan(premiumCheck));
    });

    test('requireSignInToPlay shows the sign-in dialog', () {
      final body = _member(premium, 'static Future<bool> requireSignInToPlay(');
      expect(body, contains('if (!loginRequiredForPlayback) return true;'));
      expect(body, contains('if (isSignedIn(ref)) return true;'));
      expect(body, contains('promptSignIn(context, ref)'));
    });
  });

  group('the notifier: no path starts audio without a session', () {
    final notifier =
        File('lib/provider/audio_player/audio_player.dart').readAsStringSync();

    test('the player holds the same gate as the server', () {
      expect(
        notifier.contains(
          'bool get _playbackAllowed => PremiumAccess.isPlaybackAllowed(ref);',
        ),
        isTrue,
      );
    });

    test('load, jumpToTrack and swapActiveSource are all guarded', () {
      expect(
        _count(notifier, RegExp(r'if \(!_playbackAllowed\)')),
        greaterThanOrEqualTo(3),
        reason: 'load() starts a queue, jumpToTrack() starts a queued track and '
            'swapActiveSource() restarts the current one — each can produce '
            'audio, so each must refuse without a session',
      );
    });

    test('signing out stops playback and clears the queue', () {
      expect(notifier, contains('ref.listen(clerkAuthProvider'));
      expect(notifier, contains('unawaited(stop())'));
    });

    test('a saved queue is not restored into a signed-out session', () {
      expect(notifier, contains('_playbackAllowedWhenKnown()'));
    });
  });

  group('the surfaces that start playback ask for sign-in', () {
    // Each of these bypasses `gateTrackPlay`/`gateAlbumPlay` (it drives the
    // notifier directly), so each carries its own call.
    const callSites = {
      'lib/components/track_presentation/use_action_callbacks.dart':
          'PremiumAccess.gateAlbumPlay(',
      'lib/modules/playlist/playlist_card.dart':
          'PremiumAccess.requireSignInToPlay(',
      'lib/pages/track/track.dart': 'PremiumAccess.requireSignInToPlay(',
      'lib/pages/artist/section/top_tracks.dart':
          'PremiumAccess.requireSignInToPlay(',
      'lib/modules/home/sections/specials_carousel.dart':
          'PremiumAccess.requireSignInToPlay(',
      'lib/pages/library/user_playlists.dart':
          'PremiumAccess.requireSignInToPlay(',
      'lib/provider/track_options/track_options_provider.dart':
          'PremiumAccess.requireSignInToPlay(',
      'lib/services/audio_preload/track_byte_prefetcher.dart':
          'PremiumAccess.isPlaybackAllowedNow',
    };

    for (final entry in callSites.entries) {
      test('${entry.key} gates playback', () {
        expect(
          File(entry.key).readAsStringSync().contains(entry.value),
          isTrue,
          reason: '${entry.key} starts playback (or warms audio bytes) without '
              'going through the shared gate, so it must apply the sign-in rule '
              'itself; otherwise a signed-out tap is silently ignored',
        );
      });
    }

    test('the collection play/shuffle gate runs for EVERY collection', () {
      final source = File(
        'lib/components/track_presentation/use_action_callbacks.dart',
      ).readAsStringSync();
      expect(
        source.contains('if (!PremiumAccess.isAlbumLocked(collection, ref)) return true;'),
        isFalse,
        reason: 'that early return skipped the gate for every free album and '
            'playlist, which is most of them — the collection gate must now run '
            'unconditionally',
      );
    });
  });
}
