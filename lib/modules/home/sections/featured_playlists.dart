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
/// Mirrors the design's row of circular deity buttons: a colored circle with a
/// glyph inside and the name underneath. Tapping one plays the tracks whose
/// text matches the chip's keywords.
class FeaturedPlaylist {
  /// Stable id, also the row's primary key in `featured_playlists`.
  final String id;

  /// Label shown under the circle (e.g. "Venkateswara").
  final String title;

  /// Keywords matched against a track's name/album/artists/tags. Any single
  /// hit qualifies the track. Empty means "no tracks"; such a chip is dropped.
  final List<String> keywords;

  /// Gradient endpoints for the circle. Null means "use the theme primary".
  final Color? colorFrom;
  final Color? colorTo;

  /// Name of the glyph drawn inside the circle. Unknown names fall back to a
  /// generic music glyph, so a typo can never render an empty circle.
  final String? icon;

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
    required this.tracks,
  });

  /// The gradient's first stop, falling back to [fallback] when unconfigured.
  Color colorFromOr(Color fallback) => colorFrom ?? fallback;

  /// The gradient's second stop, falling back to the first stop so a chip with
  /// a single configured color still renders a sensible (flat) circle.
  Color colorToOr(Color fallback) => colorTo ?? colorFrom ?? fallback;
}

/// An admin-managed chip row from `featured_playlists` (migration 028).
class FeaturedPlaylistRow {
  final String id;
  final String title;
  final List<String> keywords;
  final String? colorFrom;
  final String? colorTo;
  final String? icon;
  final int? sortOrder;
  final bool isHidden;

  const FeaturedPlaylistRow({
    required this.id,
    required this.title,
    required this.keywords,
    this.colorFrom,
    this.colorTo,
    this.icon,
    this.sortOrder,
    this.isHidden = false,
  });

  factory FeaturedPlaylistRow.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords']?.toString() ?? '';
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
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : int.tryParse(json['sortOrder']?.toString() ?? ''),
      isHidden: json['isHidden'] == true,
    );
  }
}

/// A built-in chip definition, used when `featured_playlists` is empty.
class _ChipDefinition {
  final String id;
  final String title;
  final List<String> keywords;
  final String colorFrom;
  final String colorTo;
  final String icon;

  const _ChipDefinition({
    required this.id,
    required this.title,
    required this.keywords,
    required this.colorFrom,
    required this.colorTo,
    required this.icon,
  });
}

/// The default chips, matching the design's row and the devotional catalogue.
///
/// These are only a fallback: any admin row in `featured_playlists` with the
/// same id overrides the title, keywords, colors and icon, and additional
/// admin rows append after these. Keywords follow the Specials shelves' proven
/// word-start rule, so a deity chip does not collect unrelated tracks.
const List<_ChipDefinition> _defaultChips = [
  _ChipDefinition(
    id: 'venkateswara',
    title: 'Venkateswara',
    keywords: ['venkateswara', 'venkateshwara', 'balaji', 'govinda', 'govind', 'tirupati', 'srinivasa', 'niluvadu'],
    colorFrom: '#f2a33c',
    colorTo: '#d97706',
    icon: 'temple',
  ),
  _ChipDefinition(
    id: 'krishna',
    title: 'Krishna',
    keywords: ['krishna', 'govardhan', 'radha', 'murali', 'gopala', 'madhav', 'keshav', 'gopika'],
    colorFrom: '#3b82f6',
    colorTo: '#1d4ed8',
    icon: 'flute',
  ),
  _ChipDefinition(
    id: 'ganesha',
    title: 'Ganesha',
    keywords: ['ganesh', 'ganesha', 'ganapati', 'ganapathi', 'vinayaka', 'vighnesh', 'vignesh', 'gajanana', 'gajanand', 'vakratunda', 'ekadanta', 'lambodara'],
    colorFrom: '#ef4444',
    colorTo: '#b91c1c',
    icon: 'ganesha',
  ),
  _ChipDefinition(
    id: 'rama',
    title: 'Rama',
    keywords: ['rama', 'sita', 'hanuman', 'ayodhya', 'raghu', 'rama raksha'],
    colorFrom: '#fb923c',
    colorTo: '#ea580c',
    icon: 'bow',
  ),
  _ChipDefinition(
    id: 'devi',
    title: 'Devi',
    keywords: ['devi', 'durga', 'lakshmi', 'laxmi', 'parvati', 'shakti', 'ambika', 'bhavani', 'kaali', 'kali', 'mahalakshmi', 'mahalaxmi'],
    colorFrom: '#ec4899',
    colorTo: '#be185d',
    icon: 'lotus',
  ),
  _ChipDefinition(
    id: 'chants',
    title: 'Chants',
    keywords: ['mantra', 'mantram', 'stotram', 'stotra', 'ashtakam', 'sahasranama', 'sahasranamam', 'suprabhatam', 'sloka', 'shloka', 'om ', 'chants'],
    colorFrom: '#8b5cf6',
    colorTo: '#6d28d9',
    icon: 'om',
  ),
];

/// The admin-managed chip rows, read through the app's own local server.
///
/// A failure (server not up yet, table absent because migration 028 was not
/// applied) resolves to an empty list so the built-in defaults apply.
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

/// Whether [keyword] occurs in [haystack] as a whole word or the start of one.
///
/// Identical to the Specials rule: a word-start match lets suffixed devotional
/// forms ("shivaya", "lingashtakam") match, while requiring the keyword to
/// start a word stops a short fragment from matching mid-word.
bool matchesKeyword(String haystack, String keyword) {
  if (keyword.contains(' ')) return haystack.contains(keyword);
  return RegExp('\\b${RegExp.escape(keyword)}').hasMatch(haystack);
}

/// Builds the Featured Playlist chips from the catalogue plus admin rows.
///
/// Admin rows win over the built-in defaults for the same id (title, keywords,
/// colors, icon), extra admin rows append in `sort_order`, and chips that end
/// up with no matching tracks are dropped so the row never shows a dead button.
final featuredPlaylistsProvider =
    FutureProvider<List<FeaturedPlaylist>>((ref) async {
  final tracks = await ref.watch(homeTracksProvider.future);
  final playCounts = await ref.watch(globalPlayCountsProvider.future);
  final rows = await ref.watch(featuredPlaylistRowsProvider.future);

  // Lowercase searchable text per track, computed once and reused per chip.
  final haystacks = <String, String>{
    for (final t in tracks) t.id: _haystackFor(t),
  };

  final rowById = {for (final r in rows) r.id: r};
  final hidden = <String>{
    for (final r in rows)
      if (r.isHidden) r.id,
  };

  // Built-in chips first, in their curated order, then any extra admin chips.
  final definitions = <_ChipDefinition>[
    ..._defaultChips.where((d) => !hidden.contains(d.id)),
    ...rows
        .where((r) =>
            !r.isHidden && !_defaultChips.any((d) => d.id == r.id))
        .map((r) => _ChipDefinition(
              id: r.id,
              title: r.title,
              keywords: r.keywords,
              colorFrom: r.colorFrom ?? '',
              colorTo: r.colorTo ?? '',
              icon: r.icon ?? '',
            )),
  ];

  final result = <FeaturedPlaylist>[];
  for (final def in definitions) {
    final row = rowById[def.id];

    // An admin row replaces the built-in title/keywords/colors/icon outright.
    final title = row?.title.isNotEmpty == true ? row!.title : def.title;
    final keywords = row != null && row.keywords.isNotEmpty
        ? row.keywords
        : def.keywords;
    // A chip with no keywords has nothing to match, so it is skipped.
    if (keywords.isEmpty) continue;

    final matched = tracks.where((t) {
      final haystack = haystacks[t.id] ?? '';
      return keywords.any((k) => matchesKeyword(haystack, k));
    }).toList();
    if (matched.isEmpty) continue;

    matched.sort((a, b) {
      final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    result.add(FeaturedPlaylist(
      id: def.id,
      title: title,
      keywords: keywords,
      colorFrom: _parseChipColor(row?.colorFrom ?? def.colorFrom),
      colorTo: _parseChipColor(row?.colorTo ?? def.colorTo),
      icon: (row?.icon?.isNotEmpty ?? false) ? row!.icon : def.icon,
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
