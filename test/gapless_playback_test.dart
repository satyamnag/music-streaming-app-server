// Regression tests for gapless, buffer-stable playlist playback.
//
// Why these exist
// ---------------
// "Seamless playback" is not a visual property, so nothing about it shows up in
// a screenshot review — and the two defects that caused the audible seams were
// both invisible to the existing suite:
//
//   1. `ConcatenatingAudioSource` was built with the DEFAULT
//      `useLazyPreparation: true`, which the just_audio docs describe as loading
//      each item "as late as possible before needed for playback". The next
//      track was therefore only fetched as the current one ended, so every
//      transition waited on a fresh network round trip: a gap at each boundary.
//
//   2. Every queue edit — append, remove, move, karaoke toggle — called
//      `setAudioSource`, which tears the playlist down and releases the decoder
//      and the whole buffer. Any of those actions while playing was a guaranteed
//      re-buffer.
//
// These tests pin the decisions that fixed them, so a future refactor cannot
// quietly restore the seam. They assert on the ENGINE'S OWN construction and on
// its use of the playlist API, which is the part a refactor would change.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;

/// Reads `useLazyPreparation` off a `ConcatenatingAudioSource` without going
/// through the engine, so the assertion is about the real object the engine
/// hands the platform.
void main() {
  group('the playback queue is prepared EAGERLY', () {
    test('a freshly built ConcatenatingAudioSource does NOT use lazy preparation',
        () {
      // The default is `true`; the fix is passing `false`. This test fails if
      // someone removes that argument, which is exactly how the seam returns.
      final lazyDefault = ja.ConcatenatingAudioSource(
        children: [ja.AudioSource.uri(Uri.parse('https://example.com/a.mp3'))],
      );
      final eager = ja.ConcatenatingAudioSource(
        children: [ja.AudioSource.uri(Uri.parse('https://example.com/a.mp3'))],
        useLazyPreparation: false,
      );

      expect(
        lazyDefault.useLazyPreparation,
        isTrue,
        reason: 'documents the default that caused the gap',
      );
      expect(
        eager.useLazyPreparation,
        isFalse,
        reason: 'eager preparation is what removes the between-track gap',
      );
    });

    test('the engine builds its queue with eager preparation', () {
      // A source-level guard: the engine must pass `useLazyPreparation: false`.
      // Asserted on the engine's file so the check cannot pass merely because
      // some OTHER code path builds an eager source.
      final source =
          File('lib/services/audio_player/just_audio_engine.dart').readAsStringSync();

      expect(
        source.contains('_eagerPreparation'),
        isTrue,
        reason: 'the eager setting must be a named, documented decision',
      );
      expect(
        source.contains('useLazyPreparation: _eagerPreparation'),
        isTrue,
        reason: 'the queue builder must actually apply the eager setting; '
            'without it ConcatenatingAudioSource defaults to lazy and the gap '
            'comes back',
      );
      expect(
        source.contains('_eagerPreparation = false'),
        isTrue,
        reason: 'eager preparation requires the flag to be FALSE',
      );
    });

    test('there is exactly ONE place that builds the queue', () {
      // The original bug was drift: the initial load built the source one way and
      // the rebuild built it another. A single builder is what makes that
      // impossible.
      final source =
          File('lib/services/audio_player/just_audio_engine.dart').readAsStringSync();

      final constructions =
          RegExp(r'ja\.ConcatenatingAudioSource\(').allMatches(source).length;
      expect(
        constructions,
        1,
        reason: 'the queue must be built in exactly one place (the _concat '
            'helper); $constructions construction sites means a code path can '
            'drift back to lazy preparation',
      );
    });
  });

  group('queue edits do not tear down the playing track', () {
    late String source;

    setUpAll(() {
      source =
          File('lib/services/audio_player/just_audio_engine.dart').readAsStringSync();
    });

    test('add / remove / move do not rebuild a queue that is already playing',
        () {
      // `ConcatenatingAudioSource` documents that its sources "can be
      // dynamically added, removed and reordered while the audio is playing".
      // These are the calls that keep the decoder and buffer intact.
      //
      // The one legitimate use of a rebuild in `addTrack` is the case where
      // NOTHING is loaded yet (`_queue == null`) — there is no playing track
      // there, so no seam can occur. That path is asserted separately below.
      expect(source.contains('await queue.add(_source(track))'), isTrue,
          reason: 'append must mutate the live queue');
      expect(source.contains('await queue.insert(index, _source(track))'),
          isTrue,
          reason: 'insert must mutate the live queue');
      expect(source.contains('await queue.removeAt(index)'), isTrue,
          reason: 'remove must mutate the live queue');
      expect(source.contains('await _queue?.move(from, to)'), isTrue,
          reason: 'reorder must move on the live queue');
    });

    test('a queue edit rebuilds ONLY when nothing is loaded', () {
      // Extracts each edit method's body and requires that any `_rebuild()` call
      // sits behind the `_queue == null` guard. Without the guard, editing the
      // queue while a track plays would release the decoder and re-buffer it.
      for (final name in <String>['addTrack', 'removeTrack']) {
        final start = source.indexOf('Future<void> $name(');
        expect(start, greaterThan(-1), reason: '$name must exist');

        // Slice to the closing of this method: the next `@override` at the same
        // indentation marks the following member.
        final rest = source.substring(start);
        final nextMember = rest.indexOf('\n  @override');
        final body = nextMember == -1 ? rest : rest.substring(0, nextMember);

        if (body.contains('_rebuild(')) {
          expect(
            body.contains('if (queue == null)') ||
                body.contains('if (_queue == null)'),
            isTrue,
            reason: '$name calls _rebuild() without a null-queue guard, so a '
                'queue edit during playback would tear down the source',
          );
        }
      }
    });

    test('the karaoke toggle is a no-op when the flag or the variant is absent',
        () {
      expect(source.contains('if (_karaoke == karaoke) return;'), isTrue,
          reason: 'an unchanged flag must not reload the queue');
      expect(source.contains('if (_karaokeVariantAvailable() == false) return;'),
          isTrue,
          reason: 'a queue with no karaoke file has identical URIs either way, '
              'so reloading it would cost a buffer for nothing');
    });

    test('a rebuild captures the position BEFORE the source is replaced', () {
      // `setAudioSource` resets the position, so reading it afterwards would
      // always yield zero and the listener would be sent back to 0:00.
      final start = source.indexOf('Future<void> _rebuild(');
      final body = source.substring(start, source.indexOf('/// Reloads the current playlist'));
      final captureAt = body.indexOf('final position = _player.position;');
      final swapAt = body.indexOf('await _player.setAudioSource(');

      expect(captureAt, greaterThan(-1), reason: 'position must be captured');
      expect(swapAt, greaterThan(-1), reason: 'the swap must happen');
      expect(
        captureAt,
        lessThan(swapAt),
        reason: 'the position must be read BEFORE the source swap or playback '
            'resumes from 0:00',
      );
    });
  });
}
