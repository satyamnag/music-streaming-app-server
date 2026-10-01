import 'package:sangeet/modules/lyrics/use_synced_lyrics.dart';
import 'package:test/test.dart';

void main() {
  // Backend SRT cues at ms precision (e.g. from an admin-authored SRT file).
  final cues = <Duration>[
    Duration(milliseconds: 5800),
    Duration(milliseconds: 9700),
    Duration(milliseconds: 13400),
  ];

  group('activeSecondFor', () {
    test('selects the last cue at or before the position', () {
      expect(
          activeSecondFor(cues, const Duration(seconds: 6, milliseconds: 200)),
          5); // after the 5.8s cue
      expect(
          activeSecondFor(cues, const Duration(seconds: 10, milliseconds: 200)),
          9); // after the 9.7s cue, before 13.4s
    });

    test('returns null before the first cue', () {
      expect(activeSecondFor(cues, const Duration(seconds: 2)), isNull);
    });

    test('exact boundaries', () {
      expect(activeSecondFor(cues, const Duration(milliseconds: 5800)), 5);
      expect(activeSecondFor(cues, const Duration(milliseconds: 9700)), 9);
      expect(activeSecondFor(cues, const Duration(milliseconds: 13400)), 13);
    });

    test('latest cue stays active across a gap (no stale hold)', () {
      expect(
          activeSecondFor(cues, const Duration(seconds: 12, milliseconds: 900)),
          9); // 12.9s < 13.4s -> 9.7s cue still active
      expect(
          activeSecondFor(cues,
              const Duration(seconds: 13, milliseconds: 500)),
          13); // 13.5s >= 13.4s cue -> 13.4s wins
    });

    test('same-second cues resolve to a single winner (last one)', () {
      final collide = <Duration>[
        Duration(milliseconds: 12200),
        Duration(milliseconds: 12800),
      ];
      expect(activeSecondFor(collide, const Duration(milliseconds: 12600)), 12);
      expect(activeSecondFor(collide, const Duration(milliseconds: 12900)), 12);
    });

    test('empty cues resolve to null', () {
      expect(activeSecondFor(const [], Duration.zero), isNull);
    });
  });
}