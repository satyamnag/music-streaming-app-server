import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lrc/lrc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/database/database.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';
import 'package:sangeet/services/logger/logger.dart';

class SyncedLyricsNotifier
    extends FamilyAsyncNotifier<SubtitleSimple, SangeetTrackObject?> {
  SangeetTrackObject get _track => arg!;

  /// Fetches lyrics stored server-side for the track from the local stream
  /// server (`/supabase/lyrics/<trackId>`), which reads the `lyrics` and
  /// `synced_lyrics` columns of the Supabase tracks table. Returns a
  /// [SubtitleSimple] with synced lines when an LRC block is present, or plain
  /// (time 0) lines when only plain lyrics exist. Returns null when the server
  /// has no lyrics for the track (caller falls back to LRCLib).
  Future<SubtitleSimple?> getServerLyrics() async {
    try {
      await SangeetMedia.ensurePortReady();
      final res = await globalDio.get(
        'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/lyrics/${_track.id}',
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (res.statusCode != 200) return null;

      final data = res.data as Map<String, dynamic>? ?? const {};
      final syncedRaw = data['synced_lyrics'] as String?;
      final plainRaw = data['lyrics'] as String?;
      final syncedEnRaw = data['synced_lyrics_en'] as String?;
      final syncedHiRaw = data['synced_lyrics_hi'] as String?;
      final syncedEnTrRaw = data['synced_lyrics_en_tr'] as String?;
      final syncedHiTrRaw = data['synced_lyrics_hi_tr'] as String?;

      if ((syncedRaw == null || syncedRaw.trim().isEmpty) &&
          (plainRaw == null || plainRaw.trim().isEmpty) &&
          (syncedEnRaw == null || syncedEnRaw.trim().isEmpty) &&
          (syncedHiRaw == null || syncedHiRaw.trim().isEmpty) &&
          (syncedEnTrRaw == null || syncedEnTrRaw.trim().isEmpty) &&
          (syncedHiTrRaw == null || syncedHiTrRaw.trim().isEmpty)) {
        return null;
      }

      Map<Duration, String>? parseLrcMap(String? raw) {
        if (raw == null || raw.trim().isEmpty) return null;
        final parsed = Lrc.parse(raw);
        return {
          for (final line in parsed.lyrics)
            if (line.lyrics.trim().isNotEmpty) line.timestamp: line.lyrics.trim(),
        };
      }

      // Build aligned multi-language rows. Every language column shares a
      // timestamp, so we merge them keyed by time and render the full set.
      final teMap = parseLrcMap(syncedRaw);
      final enMap = parseLrcMap(syncedEnRaw);
      final hiMap = parseLrcMap(syncedHiRaw);
      final enTrMap = parseLrcMap(syncedEnTrRaw);
      final hiTrMap = parseLrcMap(syncedHiTrRaw);
      final hasAnySynced = (teMap?.isNotEmpty ?? false) ||
          (enMap?.isNotEmpty ?? false) ||
          (hiMap?.isNotEmpty ?? false) ||
          (enTrMap?.isNotEmpty ?? false) ||
          (hiTrMap?.isNotEmpty ?? false);

      if (hasAnySynced) {
        final times = <Duration>{
          ...?teMap?.keys,
          ...?enMap?.keys,
          ...?hiMap?.keys,
          ...?enTrMap?.keys,
          ...?hiTrMap?.keys,
        }.toList()
          ..sort((a, b) => a.compareTo(b));

        final variants =
            times.map((t) {
              return LyricVariant(
                time: t,
                te: teMap?[t] ?? '',
                en: enMap?[t] ?? '',
                hi: hiMap?[t] ?? '',
                enTr: enTrMap?[t] ?? '',
                hiTr: hiTrMap?[t] ?? '',
              );
            }).toList();

        // Main synced list uses the Telugu (or first non-empty) line so the
        // existing single-language consumers keep working unchanged.
        final primaryRaw = syncedRaw ?? syncedEnRaw ?? syncedHiRaw;
        final primary = primaryRaw != null && primaryRaw.trim().isNotEmpty
            ? Lrc.parse(primaryRaw)
                .lyrics
                .map(LyricSlice.fromLrcLine)
                .where((s) => s.text.trim().isNotEmpty)
                .toList()
            : <LyricSlice>[];
        final slices = primary.isNotEmpty ? primary : variants.map((v) {
            final text = v.te.isNotEmpty
                ? v.te
                : v.en.isNotEmpty
                    ? v.en
                    : v.hi.isNotEmpty
                        ? v.hi
                        : v.enTr.isNotEmpty
                            ? v.enTr
                            : v.hiTr;
            return LyricSlice(time: v.time, text: text);
          }).toList();

        if (slices.isNotEmpty) {
          return SubtitleSimple(
            lyrics: slices,
            variants: variants,
            name: _track.name,
            uri: Uri.parse('server://${_track.id}'),
            rating: 100,
            provider: "Server",
          );
        }
      }

      if (plainRaw != null && plainRaw.trim().isNotEmpty) {
        final lines = plainRaw
            .split("\n")
            .map((line) => LyricSlice(text: line.trim(), time: Duration.zero))
            .where((s) => s.text.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          return SubtitleSimple(
            lyrics: lines,
            name: _track.name,
            uri: Uri.parse('server://${_track.id}'),
            rating: 0,
            provider: "Server",
          );
        }
      }

      return null;
    } catch (e) {
      AppLogger.reportError(e);
      return null;
    }
  }
  /// Lyrics credits: [lrclib.net](https://lrclib.net) and their contributors
  /// Thanks for their generous public API
  Future<SubtitleSimple> getLRCLibLyrics() async {
    final packageInfo = await PackageInfo.fromPlatform();

    final res = await globalDio.getUri(
      Uri(
        scheme: "https",
        host: "lrclib.net",
        path: "/api/get",
        queryParameters: {
          "artist_name": _track.artists.first.name,
          "track_name": _track.name,
          "album_name": _track.album.name,
          if (_track.durationMs > 0)
            "duration": (_track.durationMs / 1000).toInt().toString(),
        },
      ),
      options: Options(
        headers: {
          "User-Agent":
              "Soulful Bhakti v${packageInfo.version} (https://github.com/user/sangeet)"
        },
        responseType: ResponseType.json,
      ),
    );

    if (res.statusCode != 200) {
      return SubtitleSimple(
        lyrics: [],
        name: _track.name,
        uri: res.realUri,
        rating: 0,
        provider: "LRCLib",
      );
    }

    final json = res.data as Map<String, dynamic>;

    final syncedLyricsRaw = json["syncedLyrics"] as String?;
    final syncedLyrics = syncedLyricsRaw?.isNotEmpty == true
        ? Lrc.parse(syncedLyricsRaw!)
            .lyrics
            .map(LyricSlice.fromLrcLine)
            .toList()
        : null;

    if (syncedLyrics?.isNotEmpty == true) {
      return SubtitleSimple(
        lyrics: syncedLyrics!,
        name: _track.name,
        uri: res.realUri,
        rating: 100,
        provider: "LRCLib",
      );
    }

    final plainLyrics = (json["plainLyrics"] as String)
        .split("\n")
        .map((line) => LyricSlice(text: line, time: Duration.zero))
        .toList();

    return SubtitleSimple(
      lyrics: plainLyrics,
      name: _track.name,
      uri: res.realUri,
      rating: 0,
      provider: "LRCLib",
    );
  }

  @override
  FutureOr<SubtitleSimple> build(track) async {
    try {
      final database = ref.watch(databaseProvider);

      if (track == null) {
        throw "No track currently";
      }

      final cachedLyrics = await (database.select(database.lyricsTable)
            ..where((tbl) => tbl.trackId.equals(track.id)))
          .map((row) => row.data)
          .getSingleOrNull();

      SubtitleSimple? lyrics = cachedLyrics;

      if (lyrics == null ||
          lyrics.lyrics.isEmpty ||
          lyrics.lyrics.length <= 5) {
        // Prefer lyrics stored server-side (added via the admin web app), and
        // only fall back to LRCLib when the server has none for this track.
        lyrics = await getServerLyrics();
        if (lyrics == null || lyrics.lyrics.isEmpty) {
          lyrics = await getLRCLibLyrics();
        }
      }

      if (lyrics.lyrics.isEmpty) {
        throw Exception("Unable to find lyrics");
      }

      if (cachedLyrics == null || cachedLyrics.lyrics.isEmpty) {
        await database.into(database.lyricsTable).insert(
              LyricsTableCompanion.insert(
                trackId: track.id,
                data: lyrics,
              ),
              mode: InsertMode.replace,
            );
      }

      return lyrics;
    } catch (e, stackTrace) {
      AppLogger.reportError(e, stackTrace);
      rethrow;
    }
  }
}

final syncedLyricsDelayProvider = StateProvider<int>((ref) => 0);

final syncedLyricsProvider = AsyncNotifierProviderFamily<SyncedLyricsNotifier,
    SubtitleSimple, SangeetTrackObject?>(
  () => SyncedLyricsNotifier(),
);

final syncedLyricsMapProvider =
    FutureProvider.family((ref, SangeetTrackObject? track) async {
  final syncedLyrics = await ref.watch(syncedLyricsProvider(track).future);

  final isStaticLyrics =
      syncedLyrics.lyrics.every((l) => l.time == Duration.zero);

  final lyricsMap = syncedLyrics.lyrics
      .map((lyric) => {lyric.time.inSeconds: lyric.text})
      .reduce((accumulator, lyricSlice) => {...accumulator, ...lyricSlice});

  return (static: isStaticLyrics, lyricsMap: lyricsMap);
});
