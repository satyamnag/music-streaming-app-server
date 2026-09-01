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
      final plainEnRaw = data['plain_lyrics_en'] as String?;
      final plainHiRaw = data['plain_lyrics_hi'] as String?;
      final plainEnTrRaw = data['plain_lyrics_en_tr'] as String?;
      final plainHiTrRaw = data['plain_lyrics_hi_tr'] as String?;

      if ((syncedRaw == null || syncedRaw.trim().isEmpty) &&
          (plainRaw == null || plainRaw.trim().isEmpty) &&
          (syncedEnRaw == null || syncedEnRaw.trim().isEmpty) &&
          (syncedHiRaw == null || syncedHiRaw.trim().isEmpty) &&
          (syncedEnTrRaw == null || syncedEnTrRaw.trim().isEmpty) &&
          (syncedHiTrRaw == null || syncedHiTrRaw.trim().isEmpty) &&
          (plainEnRaw == null || plainEnRaw.trim().isEmpty) &&
          (plainHiRaw == null || plainHiRaw.trim().isEmpty) &&
          (plainEnTrRaw == null || plainEnTrRaw.trim().isEmpty)) {
        return null;
      }

      Duration? parseTimestamp(String s) {
        s = s.trim().replaceAll(',', '.');
        final parts = s.split(':');
        try {
          if (parts.length == 3) {
            final h = int.parse(parts[0].trim());
            final m = int.parse(parts[1].trim());
            final secParts = parts[2].trim().split('.');
            final sec = int.parse(secParts[0].trim());
            final msStr = secParts.length > 1 ? secParts[1].trim() : '0';
            final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
            return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
          } else if (parts.length == 2) {
            final m = int.parse(parts[0].trim());
            final secParts = parts[1].trim().split('.');
            final sec = int.parse(secParts[0].trim());
            final msStr = secParts.length > 1 ? secParts[1].trim() : '0';
            final ms = int.parse(msStr.padRight(3, '0').substring(0, 3));
            return Duration(minutes: m, seconds: sec, milliseconds: ms);
          }
        } catch (_) {
          return null;
        }
        return null;
      }

      Map<Duration, String> parseSrtMap(String raw) {
        final normalized = raw.replaceAll('\r', '').trim();
        if (normalized.isEmpty) return {};
        final blocks = normalized.split(RegExp(r'\n\s*\n'));
        final map = <Duration, String>{};
        for (final block in blocks) {
          final lines = block.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
          if (lines.isEmpty) continue;
          // First line may be numeric index
          if (RegExp(r'^\d+$').hasMatch(lines[0])) {
            lines.removeAt(0);
            if (lines.isEmpty) continue;
          }
          // Timestamp line: "00:00:01,000 --> 00:00:02,000" or "00:00:01.000 --> 00:00:02.000"
          final timeLine = lines[0];
          final arrowIdx = timeLine.indexOf('-->');
          final startStr = arrowIdx != -1 ? timeLine.substring(0, arrowIdx).trim() : timeLine.trim();
          final ts = parseTimestamp(startStr);
          if (ts == null) continue;
          final text = lines.sublist(1).join('\n').trim();
          if (text.isEmpty) continue;
          map[ts] = text;
        }
        return map;
      }

      Map<Duration, String>? parseLrcMap(String? raw) {
        if (raw == null || raw.trim().isEmpty) return null;
        // Try LRC first (LRCLib and legacy). If input is SRT (admin STR), Lrc.parse throws FormatException.
        try {
          final parsed = Lrc.parse(raw);
          final map = {
            for (final line in parsed.lyrics)
              if (line.lyrics.trim().isNotEmpty) line.timestamp: line.lyrics.trim(),
          };
          if (map.isNotEmpty) return map;
        } catch (_) {
          // Fall through to SRT
        }
        // SRT fallback: admin web interface only accepts SRT STR format (isValidSrt)
        try {
          final srtMap = parseSrtMap(raw);
          if (srtMap.isNotEmpty) return srtMap;
        } catch (_) {}
        return null;
      }

      List<LyricSlice> parseToSlices(String? raw) {
        if (raw == null || raw.trim().isEmpty) return [];
        try {
          final parsed = Lrc.parse(raw);
          final slices = parsed.lyrics.map(LyricSlice.fromLrcLine).where((s) => s.text.trim().isNotEmpty).toList();
          if (slices.isNotEmpty) return slices;
        } catch (_) {}
        // SRT fallback
        final srtMap = parseSrtMap(raw);
        if (srtMap.isEmpty) return [];
        final sorted = srtMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
        return sorted.map((e) => LyricSlice(time: e.key, text: e.value)).toList();
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
        // Handles both LRC (LRCLib) and SRT (admin STR) via parseToSlices.
        final primaryRaw = syncedRaw ?? syncedEnRaw ?? syncedHiRaw;
        final primary = parseToSlices(primaryRaw);
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

      // Plain (non-timed) lyrics: use the legacy `lyrics` column or any of the
      // per-language `plain_lyrics*` columns. Build a `SubtitleSimple` whose
      // [lyrics] lines are shown as plain text and whose [variants] carry the
      // full multilanguage (Telugu / English / Hindi × translation /
      // transliteration) set, so the Plain tab renders every available
      // language even when there are no synced/timed lyrics.
      final plainTe = (plainRaw != null && plainRaw.trim().isNotEmpty)
          ? plainRaw
          : (data['plain_lyrics'] as String?);
      final hasPlain =
          (plainTe?.trim().isNotEmpty ?? false) ||
          (plainEnRaw?.trim().isNotEmpty ?? false) ||
          (plainHiRaw?.trim().isNotEmpty ?? false) ||
          (plainEnTrRaw?.trim().isNotEmpty ?? false) ||
          (plainHiTrRaw?.trim().isNotEmpty ?? false);

      if (hasPlain) {
        // Split each language column into lines aligned by index (they are
        // stored line-per-line, same order).
        final teLines = _plainLinesOf(plainTe);
        final enLines = _plainLinesOf(plainEnRaw);
        final hiLines = _plainLinesOf(plainHiRaw);
        final enTrLines = _plainLinesOf(plainEnTrRaw);
        final hiTrLines = _plainLinesOf(plainHiTrRaw);
        final lineCount = [
          teLines.length, enLines.length, hiLines.length,
          enTrLines.length, hiTrLines.length,
        ].fold<int>(0, (m, v) => v > m ? v : m);

        final variants = <LyricVariant>[];
        final slices = <LyricSlice>[];
        for (var i = 0; i < lineCount; i++) {
          final te = i < teLines.length ? teLines[i] : '';
          final en = i < enLines.length ? enLines[i] : '';
          final hi = i < hiLines.length ? hiLines[i] : '';
          final enTr = i < enTrLines.length ? enTrLines[i] : '';
          final hiTr = i < hiTrLines.length ? hiTrLines[i] : '';
          final first = (te.isNotEmpty ? te : en.isNotEmpty ? en : hi.isNotEmpty ? enTr : hiTr);
          if (first.isEmpty) continue;
          variants.add(LyricVariant(
            time: Duration.zero, te: te, en: en, hi: hi, enTr: enTr, hiTr: hiTr,
          ));
          slices.add(LyricSlice(text: first, time: Duration.zero));
        }

        if (slices.isNotEmpty) {
          return SubtitleSimple(
            lyrics: slices,
            variants: variants,
            name: _track.name,
            uri: Uri.parse('server://${_track.id}'),
            rating: 0,
            provider: "Server",
          );
        }
      }

      // Last-resort salvage: if the database has lyrics text but neither the
      // LRC/SRT (synced) parser nor the `lyrics` plain column produced a set
      // (e.g. an unusual or unparseable format), show the raw text as plain
      // lines rather than silently reporting "no lyrics". This guarantees any
      // available lyrics surface on screen.
      final anyRaw = syncedRaw ?? syncedEnRaw ?? syncedHiRaw ?? syncedEnTrRaw ?? syncedHiTrRaw;
      if (anyRaw != null && anyRaw.trim().isNotEmpty) {
        final lines = anyRaw
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((s) => s.isNotEmpty)
            .map((s) => LyricSlice(text: s, time: Duration.zero))
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

    final plainLyricsRaw = json["plainLyrics"] as String?;
    if (plainLyricsRaw == null || plainLyricsRaw.trim().isEmpty) {
      // No synced and no plain lyrics from the provider: return an empty set
      // (never throw) so the app shows a clean "no lyrics available" state
      // rather than a crash/error.
      return SubtitleSimple(
        lyrics: [],
        name: _track.name,
        uri: res.realUri,
        rating: 0,
        provider: "LRCLib",
      );
    }

    final plainLyrics = plainLyricsRaw
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

      // Always prefer the server/Database lyrics (added via the admin app) —
      // they are the source of truth and must display regardless of line
      // count (e.g. a 5-line lyric set). Only fall back to LRCLib when the
      // server genuinely has no lyrics for the track.
      final serverLyrics = await getServerLyrics();
      if (serverLyrics != null &&
          (serverLyrics.lyrics.isNotEmpty || (serverLyrics.variants?.isNotEmpty ?? false))) {
        lyrics = serverLyrics;
      } else {
        if (lyrics == null || lyrics.lyrics.isEmpty) {
          lyrics = await getLRCLibLyrics();
        }
      }

      if (lyrics == null || lyrics.lyrics.isEmpty) {
        throw Exception("Unable to find lyrics");
      }

      // Persist fresh server lyrics so an updated plain/sync set is reflected
      // immediately and on subsequent opens.
      await database.into(database.lyricsTable).insert(
            LyricsTableCompanion.insert(
              trackId: track.id,
              data: lyrics,
            ),
            mode: InsertMode.replace,
          );

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

/// Splits a per-language plain-lyrics string into cleaned non-empty lines.
/// Used to align the multilingual `plain_lyrics*` columns line-by-line so each
/// translation/transliteration maps to the same lyric index.
List<String> _plainLinesOf(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}
