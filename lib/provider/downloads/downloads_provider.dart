import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/services/downloads_index/downloads_index.dart';

class DownloadedTracksNotifier extends Notifier<List<DownloadedTrack>> {
  @override
  List<DownloadedTrack> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    state = await DownloadsIndexService.load();
  }

  Future<void> addOrUpdate(DownloadedTrack track) async {
    final updated = [
      track,
      ...state.where((e) => e.trackId != track.trackId),
    ];
    state = updated;
    await DownloadsIndexService.save(updated);
  }

  Future<void> remove(String trackId) async {
    final updated = state.where((e) => e.trackId != trackId).toList();
    state = updated;
    await DownloadsIndexService.save(updated);
  }
}

final downloadedTracksProvider =
    NotifierProvider<DownloadedTracksNotifier, List<DownloadedTrack>>(
  DownloadedTracksNotifier.new,
);
