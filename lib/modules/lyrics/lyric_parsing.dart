/// Timestamped-lyric parsing for the admin's `synced_lyrics*` columns.
///
/// WHY THIS IS ITS OWN MODULE
/// --------------------------
/// The catalogue stores TWO different formats in that column, and they are not
/// interchangeable:
///
///   * **LRC** - `[mm:ss.xx]line`, what LRCLib returns and what the legacy rows
///     hold;
///   * **SRT** - `1` / `00:00:10,427 --> 00:00:12,595` / `line`, which is what the
///     admin web interface accepts (`isValidSrt`) and therefore what most of this
///     catalogue actually contains.
///
/// The parser used to try LRC first and fall back to SRT only when the LRC result
/// was empty. Which one runs first decides whether a track has synced lyrics at
/// all, so it lives here where a unit test can hold both formats to account
/// against real payloads instead of only being exercised by opening the app.
///
/// SRT is identified by its `-->` arrow, which LRC never contains, and is parsed
/// FIRST when present. That is a format marker, not a guess.
library;

import 'package:lrc/lrc.dart';
import 'package:sangeet/models/lyrics.dart';

/// True when [raw] is SRT: cues are separated by a `-->` arrow between two
/// timestamps, a marker LRC does not use at all.
bool looksLikeSrt(String raw) => raw.contains('-->');

/// Parses one timestamp, with either a comma or a dot as the decimal separator
/// (`00:00:10,427`, `00:10.4`, `1:02:03.500`), or null when it is not one.
Duration? parseLyricTimestamp(String value) {
  final s = value.trim().replaceAll(',', '.');
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

/// Parses SRT cues into `start time -> text`, keyed by each cue's START.
///
/// Returns an empty map for text that carries no cues, so the caller can fall
/// back to another format.
Map<Duration, String> parseSrtCues(String raw) {
  final normalized = raw.replaceAll('\r', '').trim();
  if (normalized.isEmpty) return const <Duration, String>{};
  final blocks = normalized.split(RegExp(r'\n\s*\n'));
  final map = <Duration, String>{};
  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;
    // The first line of a cue may be a numeric index.
    if (RegExp(r'^\d+$').hasMatch(lines[0])) {
      lines.removeAt(0);
      if (lines.isEmpty) continue;
    }
    // Timestamp line: "00:00:01,000 --> 00:00:02,000".
    final timeLine = lines[0];
    final arrowIdx = timeLine.indexOf('-->');
    final startStr =
        arrowIdx != -1 ? timeLine.substring(0, arrowIdx).trim() : timeLine.trim();
    final ts = parseLyricTimestamp(startStr);
    if (ts == null) continue;
    final text = lines.sublist(1).join('\n').trim();
    if (text.isEmpty) continue;
    map[ts] = text;
  }
  return map;
}

/// Parses whichever timed format [raw] holds into `start time -> text`, or null
/// when it carries no timed cues at all.
///
/// SRT is tried first when the `-->` marker is present, then LRC, then SRT again
/// for text that carries the format without its arrow.
Map<Duration, String>? parseTimedCues(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final text = raw;

  if (looksLikeSrt(text)) {
    final srt = parseSrtCues(text);
    if (srt.isNotEmpty) return srt;
  }

  try {
    final parsed = Lrc.parse(text);
    final map = <Duration, String>{
      for (final line in parsed.lyrics)
        if (line.lyrics.trim().isNotEmpty) line.timestamp: line.lyrics.trim(),
    };
    if (map.isNotEmpty) return map;
  } catch (_) {
    // Not LRC: fall through to SRT.
  }

  final srt = parseSrtCues(text);
  if (srt.isNotEmpty) return srt;
  return null;
}

/// Parses [raw] into a flat, timestamp-ordered list of slices for the
/// single-language consumers (the main lyric list and the active-line lookup).
List<LyricSlice> parseTimedSlices(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <LyricSlice>[];

  if (looksLikeSrt(raw)) {
    final srt = parseSrtCues(raw);
    if (srt.isNotEmpty) return _slicesOf(srt);
  }

  try {
    final parsed = Lrc.parse(raw);
    final slices = parsed.lyrics
        .map(LyricSlice.fromLrcLine)
        .where((s) => s.text.trim().isNotEmpty)
        .toList();
    if (slices.isNotEmpty) return slices;
  } catch (_) {
    // Not LRC: fall through to SRT.
  }

  return _slicesOf(parseSrtCues(raw));
}

/// True when at least one cue has a real timestamp, i.e. the lyrics are SYNCED
/// rather than a plain set of lines stored as time zero.
///
/// Callers use this to decide whether the Sync tab has anything to show. It is
/// deliberately computed from the lyrics themselves: gating on a separate
/// provider's state blanked the tab whenever that provider was still loading.
bool hasRealTimings(Iterable<Duration> times) =>
    times.any((time) => time != Duration.zero);

List<LyricSlice> _slicesOf(Map<Duration, String> cues) {
  if (cues.isEmpty) return const <LyricSlice>[];
  final sorted = cues.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return [
    for (final entry in sorted) LyricSlice(time: entry.key, text: entry.value),
  ];
}
