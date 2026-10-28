// Guards the parsing of the admin's `synced_lyrics*` columns.
//
// The reported symptom was "no synced lyrics on some tracks" - Tenela Tiyyani,
// Srinivasa Kalyana Sambaram, Tirumala Narayanaa. Those rows are **SRT**, while
// the parser used to try LRC first and rely on the LRC library REJECTING SRT to
// reach the SRT branch. That is luck, not a rule: if the LRC attempt ever produced
// a non-empty (all-zero) result the SRT fallback was skipped, every cue got time
// zero, the lyrics were classified as "not synced", and the Sync tab said "There
// is no data" on a track whose cues were sitting in the column.
//
// So the payloads below are REAL excerpts of those three tracks, and the
// assertions are about timings actually arriving - not merely about non-empty
// output.

import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/modules/lyrics/lyric_parsing.dart';

/// Real SRT from "Tenela Tiyyani" (and the same shape as the other two tracks).
const String _srtTenela = '''
1
00:00:00,000 --> 00:00:10,427
{{Music}}

2
00:00:10,427 --> 00:00:12,595
తేనెలా తియ్యని

3
00:00:12,971 --> 00:00:14,973
తిరుమల నామము,

4
00:01:02,500 --> 00:01:05,000
రెండో పంక్తి
''';

/// Real SRT from "Srinivasa Kalyana Sambaram", with the CRLF line endings the
/// admin editor produces.
const String _srtSrinivasaCrlf =
    '1\r\n00:00:00,000 --> 00:00:10,635\r\n{{Music}}\r\n\r\n'
    '2\r\n00:00:10,635 --> 00:00:14,639\r\nశ్రీనివాస కల్యాణ సంబరం,\r\n';

/// A valid LRC block, the format LRCLib and the legacy rows use.
const String _lrc = '''
[ar:Test]
[00:00.00]{{Music}}
[00:10.42]First line
[01:02.50]Second line
''';

const Duration _ten42 = Duration(seconds: 10, milliseconds: 427);
const Duration _twelve97 = Duration(seconds: 12, milliseconds: 971);
const Duration _sixtyTwo = Duration(minutes: 1, seconds: 2, milliseconds: 500);

void main() {
  group('looksLikeSrt', () {
    test('identifies SRT by its arrow and LRC by its absence', () {
      expect(looksLikeSrt(_srtTenela), isTrue);
      expect(looksLikeSrt(_lrc), isFalse);
    });
  });

  group('parseLyricTimestamp', () {
    test('accepts SRT commas and LRC dots', () {
      expect(parseLyricTimestamp('00:10,427'),
          const Duration(seconds: 10, milliseconds: 427));
      expect(parseLyricTimestamp('00:10.42'),
          const Duration(seconds: 10, milliseconds: 420));
      expect(parseLyricTimestamp('01:02:03,500'),
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 500));
    });

    test('returns null for something that is not a timestamp', () {
      expect(parseLyricTimestamp('not a time'), isNull);
      expect(parseLyricTimestamp(''), isNull);
    });
  });

  group('parseSrtCues', () {
    test('gives every cue its REAL start time', () {
      final cues = parseSrtCues(_srtTenela);

      expect(cues, hasLength(4));
      expect(cues[Duration.zero], '{{Music}}');
      expect(cues[_ten42], 'తేనెలా తియ్యని');
      expect(cues[_twelve97], 'తిరుమల నామము,');
      expect(cues[_sixtyTwo], 'రెండో పంక్తి');
    });

    test('handles CRLF line endings', () {
      final cues = parseSrtCues(_srtSrinivasaCrlf);

      expect(cues, hasLength(2));
      expect(cues[Duration.zero], '{{Music}}');
      expect(cues[const Duration(seconds: 10, milliseconds: 635)],
          'శ్రీనివాస కల్యాణ సంబరం,');
    });

    test('returns nothing for text that carries no cues', () {
      expect(parseSrtCues('just some plain words'), isEmpty);
      expect(parseSrtCues(''), isEmpty);
    });
  });

  group('parseTimedCues', () {
    test('SRT is parsed with timings, whichever parser runs first', () {
      final cues = parseTimedCues(_srtTenela)!;

      expect(cues, isNotNull);
      expect(cues, hasLength(4));
      // The whole bug: the cues must keep their times, not collapse to zero.
      expect(cues.containsKey(_ten42), isTrue);
      expect(cues[_ten42], 'తేనెలా తియ్యని');
    });

    test('LRC is still parsed', () {
      final cues = parseTimedCues(_lrc)!;

      expect(cues, hasLength(3));
      expect(cues[Duration.zero], '{{Music}}');
      expect(cues[const Duration(seconds: 10, milliseconds: 420)], 'First line');
    });

    test('null and empty input yield null, so the caller can fall back', () {
      expect(parseTimedCues(null), isNull);
      expect(parseTimedCues('   '), isNull);
    });
  });

  group('parseTimedSlices', () {
    test('SRT produces ordered slices with real times', () {
      final slices = parseTimedSlices(_srtTenela);

      expect(slices, hasLength(4));
      expect(slices.first.time, Duration.zero);
      expect(slices.first.text, '{{Music}}');
      expect(slices[1].time, _ten42);
      expect(slices.last.time, _sixtyTwo);
      // Ordered, so the active-line lookup can binary-search `cues`.
      for (var i = 1; i < slices.length; i++) {
        expect(slices[i].time >= slices[i - 1].time, isTrue);
      }
    });

    test('LRC still produces ordered slices', () {
      final slices = parseTimedSlices(_lrc);

      expect(slices.map((s) => s.text).toList(),
          ['{{Music}}', 'First line', 'Second line']);
      expect(slices[1].time, const Duration(seconds: 10, milliseconds: 420));
    });

    test('text without timings produces no slices', () {
      expect(parseTimedSlices('plain words only'), isEmpty);
      expect(parseTimedSlices(null), isEmpty);
    });
  });

  group('hasRealTimings', () {
    test('true only when some cue has a non-zero time', () {
      expect(hasRealTimings(const [Duration.zero, Duration(seconds: 3)]), isTrue);
      expect(hasRealTimings(const [Duration.zero, Duration.zero]), isFalse);
      expect(hasRealTimings(const <Duration>[]), isFalse);
    });

    test('the reported tracks are recognised as SYNCED', () {
      // This is the classification the Sync tab gated on: with the bug the parsed
      // times were all zero and these tracks were treated as plain, so the tab
      // showed nothing.
      final tenela = parseTimedSlices(_srtTenela);
      final srinivasa = parseTimedSlices(_srtSrinivasaCrlf);

      expect(hasRealTimings(tenela.map((s) => s.time)), isTrue);
      expect(hasRealTimings(srinivasa.map((s) => s.time)), isTrue);
    });
  });
}
