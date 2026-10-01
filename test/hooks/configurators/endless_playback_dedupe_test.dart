import 'package:sangeet/hooks/configurators/use_endless_playback.dart';
import 'package:sangeet/collections/fake.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:test/test.dart';

void main() {
  SangeetTrackObject t(String id) => SangeetTrackObject.full(
        id: id,
        name: 'Track $id',
        externalUri: 'https://example.com/$id',
        album: FakeData.albumSimple,
        durationMs: 180000,
        isrc: 'ISRC-$id',
        explicit: false,
      );

  group('dedupeRadioTracks', () {
    test('drops the current track and queue duplicates, keeps order', () {
      final queue = [t('a'), t('b')];
      final radio = [t('a'), t('x'), t('b'), t('z')];

      final result = dedupeRadioTracks(radio, queue, 'a');

      expect(result.map((e) => e.id), ['x', 'z']);
    });

    test('keeps everything when nothing is a duplicate', () {
      final result = dedupeRadioTracks([t('p'), t('q')], [t('a')], 'a');
      expect(result.map((e) => e.id), ['p', 'q']);
    });

    test('returns empty when every candidate is already queued', () {
      final result = dedupeRadioTracks([t('a'), t('b')], [t('a'), t('b')], 'a');
      expect(result, isEmpty);
    });

    test('handles an empty queue and empty radio result', () {
      expect(dedupeRadioTracks(const [], [], 'a'), isEmpty);
      expect(dedupeRadioTracks([t('x')], const [], 'a').single.id, 'x');
    });
  });
}