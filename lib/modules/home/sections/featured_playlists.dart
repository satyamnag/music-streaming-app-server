import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';
import 'package:sangeet/provider/server/server.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';

/// One "Featured Playlist" chip shown as a round button under the home
/// carousel (e.g. "Venkateswara", "Krishna", "Ganesha").
///
/// Mirrors the design's row of circular deity buttons: a colored circle with an
/// admin-chosen icon inside and the name underneath. Tapping one plays the
/// tracks the admin put in it (plus, optionally, tracks its keywords match).
class FeaturedPlaylist {
  /// Stable id, also the row's primary key in `featured_playlists`.
  final String id;

  /// Label shown under the circle (e.g. "Venkateswara").
  final String title;

  /// Keywords matched against a track's name/album/artists/tags. Any single
  /// hit qualifies the track. Only used when the admin left `match_keywords`
  /// on; an empty list simply contributes no keyword matches.
  final List<String> keywords;

  /// Gradient endpoints for the circle. Null means "use the theme primary".
  final Color? colorFrom;
  final Color? colorTo;

  /// Name of the glyph drawn inside the circle. Unknown names fall back to a
  /// generic music glyph, so a typo can never render an empty circle.
  final String? icon;

  /// Admin-uploaded icon image for the circle. When set it is drawn instead of
  /// [icon], so the admin can put any artwork on a chip; [icon] remains the
  /// fallback, which means the circle is never blank.
  final String? iconUrl;

  /// The chip's tracks, most played first. Never empty (empty chips are
  /// dropped by the provider).
  final List<SangeetTrackObject> tracks;

  const FeaturedPlaylist({
    required this.id,
    required this.title,
    required this.keywords,
    this.colorFrom,
    this.colorTo,
    this.icon,
    this.iconUrl,
    required this.tracks,
  });

  /// The gradient's first stop, falling back to [fallback] when unconfigured.
  Color colorFromOr(Color fallback) => colorFrom ?? fallback;

  /// The gradient's second stop, falling back to the first stop so a chip with
  /// a single configured color still renders a sensible (flat) circle.
  Color colorToOr(Color fallback) => colorTo ?? colorFrom ?? fallback;
}

/// An admin-managed chip row from `featured_playlists` (migrations 028 + 029).
class FeaturedPlaylistRow {
  final String id;
  final String title;
  final List<String> keywords;
  final String? colorFrom;
  final String? colorTo;
  final String? icon;

  /// Admin-uploaded icon image URL (029). Wins over [icon] when set.
  final String? iconUrl;

  /// Whether [keywords] add matching tracks on top of [trackIds]. False means
  /// the admin controls membership entirely by hand.
  final bool matchKeywords;

  /// The explicit, ordered track ids the admin picked in the admin panel (029).
  final List<String> trackIds;

  final int? sortOrder;
  final bool isHidden;

  const FeaturedPlaylistRow({
    required this.id,
    required this.title,
    required this.keywords,
    this.colorFrom,
    this.colorTo,
    this.icon,
    this.iconUrl,
    this.matchKeywords = true,
    this.trackIds = const [],
    this.sortOrder,
    this.isHidden = false,
  });

  factory FeaturedPlaylistRow.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords']?.toString() ?? '';
    final rawTracks = json['trackIds'];
    return FeaturedPlaylistRow(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      keywords: rawKeywords
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty)
          .toList(),
      colorFrom: json['colorFrom']?.toString(),
      colorTo: json['colorTo']?.toString(),
      icon: json['icon']?.toString(),
      iconUrl: json['iconUrl']?.toString(),
      // Only an explicit false turns the rule off, so a missing field from an
      // older server keeps the pre-migration behaviour of matching by keyword.
      matchKeywords: json['matchKeywords'] != false,
      trackIds: rawTracks is List
          ? rawTracks
              .map((t) => t.toString().trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : const [],
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
      isHidden: json['isHidden'] == true,
    );
  }
}

/// The admin-managed chip rows, read through the app's own local server.
///
/// A failure (server not up yet, or the table missing because migration 028 was
/// not applied) resolves to an empty list, which means no chips rather than an
/// error on the home screen.
final featuredPlaylistRowsProvider =
    FutureProvider<List<FeaturedPlaylistRow>>((ref) async {
  await ref.watch(serverProvider.future);
  await SangeetMedia.ensurePortReady();

  try {
    final response = await globalDio.get(
      'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/featured-playlists',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'accept': 'application/json'},
      ),
    );
    if (response.statusCode != 200) return const [];
    final body = response.data;
    final rawItems = body is Map<String, dynamic>
        ? (body['items'] as List<dynamic>? ?? const [])
        : const <dynamic>[];
    return rawItems
        .map((e) => FeaturedPlaylistRow.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .where((r) => r.id.isNotEmpty && r.title.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
});

/// Admin order for chips: an explicit `sort_order` first (ascending), then
/// unordered rows by title. Without the title tiebreak the chip row's order
/// would depend on whatever order the rows happened to come back in.
int _byAdminOrder(FeaturedPlaylistRow a, FeaturedPlaylistRow b) {
  final ao = a.sortOrder;
  final bo = b.sortOrder;
  if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
  if (ao != null && bo == null) return -1;
  if (ao == null && bo != null) return 1;
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Whether [keyword] occurs in [haystack] as a whole word or the start of one.
///
/// Identical to the Specials rule: a word-start match lets suffixed devotional
/// forms ("shivaya", "lingashtakam") match, while requiring the keyword to
/// start a word stops a short fragment from matching mid-word.
bool matchesKeyword(String haystack, String keyword) {
  if (keyword.contains(' ')) return haystack.contains(keyword);
  return RegExp('\\b${RegExp.escape(keyword)}').hasMatch(haystack);
}

/// Builds the Featured Playlist chips from the admin's rows.
///
/// There is no built-in chip list any more: an empty `featured_playlists` table
/// means no chips. For each row the admin has not hidden, membership is the
/// union of:
///   * the EXPLICIT track list ([FeaturedPlaylistRow.trackIds]), in the admin's
///     own order, and
///   * tracks matching the row's keywords, when
///     [FeaturedPlaylistRow.matchKeywords] is on.
/// Keyword-matched tracks are ordered by global play count (most played first),
/// then by name. A chip that ends up with no tracks is dropped, so the row never
/// shows a dead button.
final featuredPlaylistsProvider =
    FutureProvider<List<FeaturedPlaylist>>((ref) async {
  final tracks = await ref.watch(homeTracksProvider.future);
  final playCounts = await ref.watch(globalPlayCountsProvider.future);
  final rows = await ref.watch(featuredPlaylistRowsProvider.future);

  if (tracks.isEmpty || rows.isEmpty) return const [];

  final byId = <String, SangeetTrackObject>{
    for (final t in tracks) t.id: t,
  };
  // Lowercase searchable text per track, computed once and reused per chip.
  final haystacks = <String, String>{
    for (final t in tracks) t.id: _haystackFor(t),
  };

  final result = <FeaturedPlaylist>[];
  // Admin order, so the row reads the way the admin arranged it.
  final ordered = [...rows]..sort(_byAdminOrder);
  for (final row in ordered) {
    // An admin-hidden chip is dropped regardless of how many tracks it holds.
    if (row.isHidden || row.title.isEmpty) continue;

    final matched = <SangeetTrackObject>[];
    final seen = <String>{};
    for (final id in row.trackIds) {
      final track = byId[id];
      if (track == null || !seen.add(id)) continue;
      matched.add(track);
    }

    if (row.matchKeywords && row.keywords.isNotEmpty) {
      final extra = tracks.where((t) {
        if (seen.contains(t.id)) return false;
        final haystack = haystacks[t.id] ?? '';
        return row.keywords.any((k) => matchesKeyword(haystack, k));
      }).toList()
        ..sort((a, b) {
          final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });
      matched.addAll(extra);
    }

    if (matched.isEmpty) continue;

    result.add(FeaturedPlaylist(
      id: row.id,
      title: row.title,
      keywords: row.keywords,
      colorFrom: _parseChipColor(row.colorFrom),
      colorTo: _parseChipColor(row.colorTo),
      icon: row.icon,
      iconUrl: row.iconUrl,
      tracks: matched,
    ));
  }

  return result;
});

/// Lowercase searchable text for a track: name, album, artists and tags.
String _haystackFor(SangeetTrackObject track) {
  final parts = <String>[
    track.name,
    track.album.name,
    ...track.artists.map((a) => a.name),
    if (track is SangeetFullTrackObject) track.tags ?? '',
  ];
  return parts.join(' ').toLowerCase();
}

/// Parses a chip color (`#rrggbb` or `#rgb`) into a [Color], or null when the
/// value is absent/malformed so the caller can fall back to the theme.
Color? _parseChipColor(String? value) {
  if (value == null) return null;
  var hex = value.trim();
  if (hex.isEmpty) return null;
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length != 6) return null;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}

/// The admin-managed home-screen wallpaper URL, or null when unset.
///
/// A failure (server not up, table absent because migration 028 was not
/// applied, or an empty value) resolves to null so the home screen renders
/// normally without a wallpaper instead of showing a broken background.
final homeWallpaperProvider = FutureProvider<String?>((ref) async {
  await ref.watch(serverProvider.future);
  await SangeetMedia.ensurePortReady();

  try {
    final response = await globalDio.get(
      'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/home-wallpaper',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'accept': 'application/json'},
      ),
    );
    if (response.statusCode != 200) return null;
    final body = response.data;
    if (body is! Map<String, dynamic>) return null;
    final url = body['url']?.toString().trim();
    return (url == null || url.isEmpty) ? null : url;
  } catch (_) {
    return null;
  }
});
