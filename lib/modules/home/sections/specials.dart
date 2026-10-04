import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';
import 'package:sangeet/provider/server/server.dart';
import 'package:sangeet/services/audio_player/audio_player.dart';
import 'package:sangeet/services/dio/dio.dart';

/// One curated "Special" shelf shown as a full-width carousel on the home
/// screen (e.g. "Ganesha Special").
class HomeSpecial {
  /// Stable id (also used as the Widget key so slides are recycled correctly).
  final String id;

  /// Display title, e.g. "Ganesha Special".
  final String title;

  /// Short supporting line under the title.
  final String subtitle;

  /// Cover for the slide: the admin-uploaded landscape banner when set,
  /// otherwise the most-played track's art in this shelf.
  final String imageUrl;

  /// True when [imageUrl] is an admin-uploaded landscape banner (8:3 WebP)
  /// rather than a square track cover. The slide uses it as a full-bleed
  /// background instead of a square thumbnail.
  final bool hasBanner;

  /// The shelf's tracks, most played first. Never empty (empty shelves are
  /// dropped by the provider).
  final List<SangeetTrackObject> tracks;

  const HomeSpecial({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.hasBanner = false,
    required this.tracks,
  });
}

/// One shelf row from the `specials` table.
///
/// The table is the ONLY source of truth for the home carousel — the app no
/// longer carries a built-in shelf list. The admin decides each shelf's title,
/// subtitle, banner, order and visibility, which tracks it holds by hand
/// ([trackIds]), and whether its [keywords] add matching tracks on top.
class HomeSpecialRow {
  final String id;
  final String? title;
  final String? subtitle;
  final String? bannerUrl;

  /// Matching rule, already split and lowercased.
  final List<String> keywords;

  /// Whether [keywords] add matching tracks on top of [trackIds]. False means
  /// the admin controls membership entirely by hand.
  final bool matchKeywords;

  /// The explicit, ordered track ids the admin picked in the admin panel.
  final List<String> trackIds;

  final int? sortOrder;
  final bool isHidden;

  const HomeSpecialRow({
    required this.id,
    this.title,
    this.subtitle,
    this.bannerUrl,
    this.keywords = const [],
    this.matchKeywords = true,
    this.trackIds = const [],
    this.sortOrder,
    this.isHidden = false,
  });

  factory HomeSpecialRow.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords']?.toString() ?? '';
    final rawTracks = json['trackIds'];
    return HomeSpecialRow(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      bannerUrl: json['bannerUrl']?.toString(),
      keywords: rawKeywords
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty)
          .toList(),
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

/// Whether [keyword] occurs in [haystack] as a whole word, or as the start of
/// one (with at least [minPrefix] characters of the keyword present).
///
/// Two failure modes drove this rule:
///  - Plain substring matching is too loose for short words: `ram` matches
///    inside the artist name "Vani Jairam", filing a Krishna bhajan under
///    "Rama Special".
///  - Strict word boundaries are too tight for Sanskrit devotional names,
///    which inflect with suffixes: `shiva` would not match "Shivaya",
///    `linga` would not match "Lingashtakam", `rudra` would not match "Rudram".
///
/// So a keyword matches when it starts a word (a boundary before it). The
/// trailing side is left open so suffixed forms match. To stop that open end
/// from reintroducing the first bug, short keywords must be at least
/// [minPrefix] characters long before a prefix match is allowed — `shiva`
/// (5) may match "shivaya", while the "ram" case is handled by the Rama shelf
/// using `rama`/`raghu` rather than a 3-letter fragment.
bool _keywordMatches(String haystack, String keyword) {
  if (keyword.contains(' ')) return haystack.contains(keyword);
  final escaped = RegExp.escape(keyword);
  // Word-start match: lets suffixed forms ("shivaya") match "shiva".
  return RegExp('\\b$escaped').hasMatch(haystack);
}

/// Builds the "Special" shelves from the admin's rows.
///
/// There is no built-in shelf list any more: an empty `specials` table means
/// no carousels. For each row the admin has not hidden, membership is the union
/// of:
///   * the EXPLICIT track list ([HomeSpecialRow.trackIds]), in the admin's own
///     order, and
///   * tracks matching the row's keywords, when [HomeSpecialRow.matchKeywords]
///     is on.
/// Keyword-matched tracks are ordered by global play count (most played first),
/// then by name, so the slide's cover is the shelf's most popular artwork. A
/// shelf that ends up with no tracks is dropped, so the home screen never shows
/// an empty carousel.
List<HomeSpecial> _buildSpecials(
  List<SangeetTrackObject> tracks,
  Map<String, int> playCounts,
  List<HomeSpecialRow> rows,
) {
  if (tracks.isEmpty || rows.isEmpty) return const [];

  final byId = <String, SangeetTrackObject>{
    for (final t in tracks) t.id: t,
  };
  // Pre-compute one lowercase haystack per track (name + album + artists +
  // tags) so matching is a single pass per shelf rather than re-joining
  // strings for every keyword.
  final haystacks = <String, String>{
    for (final t in tracks) t.id: _haystackFor(t),
  };

  final specials = <HomeSpecial>[];
  // Covers already claimed by an earlier shelf, so no two shelves show the same
  // artwork when they have no admin banner of their own.
  final usedCovers = <String>{};
  // Admin order, so the carousel reads the way the admin arranged it.
  final ordered = [...rows]..sort(_byAdminOrder);
  for (final row in ordered) {
    // An admin-hidden shelf is dropped regardless of how many tracks it holds.
    if (row.isHidden) continue;

    final title = row.title?.trim() ?? '';
    if (title.isEmpty) continue;

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
        return row.keywords.any((k) => _keywordMatches(haystack, k));
      }).toList()
        ..sort((a, b) {
          final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });
      matched.addAll(extra);
    }

    if (matched.isEmpty) continue;

    // The admin banner (if any) wins; otherwise the shelf's own track art.
    final bannerUrl = row.bannerUrl?.trim() ?? '';
    final hasBanner = bannerUrl.isNotEmpty;

    specials.add(HomeSpecial(
      id: row.id,
      title: title,
      subtitle: row.subtitle?.trim() ?? '',
      imageUrl: hasBanner ? bannerUrl : _coverFor(matched, usedCovers),
      hasBanner: hasBanner,
      tracks: matched,
    ));
  }

  return specials;
}

/// Lowercase searchable text for a track: its name, album, artists and tags.
String _haystackFor(SangeetTrackObject track) {
  final parts = <String>[
    track.name,
    track.album.name,
    ...track.artists.map((a) => a.name),
    if (track is SangeetFullTrackObject) track.tags ?? '',
  ];
  return parts.join(' ').toLowerCase();
}

/// Best available cover for a shelf: the first (most played) track that has
/// artwork, skipping any cover already used by an earlier shelf; falling back
/// to the shared album-art placeholder.
///
/// [used] is mutated so the caller can keep one cover per shelf. Without it two
/// shelves whose lead track is shared (Venkateswara and Krishna both leading
/// with the same track) rendered identical tiles in the carousel.
String _coverFor(List<SangeetTrackObject> tracks, Set<String> used) {
  for (final track in tracks) {
    final url = track.album.images.smallest(ImagePlaceholder.albumArt);
    if (url.isNotEmpty && !used.contains(url)) {
      used.add(url);
      return url;
    }
  }
  // Every cover this shelf could use is already taken; reuse its first one
  // rather than showing nothing.
  for (final track in tracks) {
    final url = track.album.images.smallest(ImagePlaceholder.albumArt);
    if (url.isNotEmpty) return url;
  }
  return '';
}

/// The admin-managed shelf rows: title, subtitle, banner, order, hidden flag,
/// the hand-picked track list and the optional keyword rule.
///
/// Read through the app's own local server (`/supabase/specials`) like every
/// other catalogue call. A failure (server not up yet, or migration 029 not
/// applied) resolves to an empty list — no carousels — rather than an error
/// screen.
final homeSpecialRowsProvider =
    FutureProvider<List<HomeSpecialRow>>((ref) async {
  await ref.watch(serverProvider.future);
  await SangeetMedia.ensurePortReady();

  try {
    final response = await globalDio.get(
      'http://127.0.0.1:${SangeetMedia.serverPort}/supabase/specials',
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        headers: {'accept': 'application/json'},
      ),
    );
    if (response.statusCode != 200) return const [];
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map((e) =>
            HomeSpecialRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((r) => r.id.isNotEmpty)
        .toList();
  } catch (_) {
    return const [];
  }
});

/// Admin order for shelves: an explicit `sort_order` first (ascending), then
/// unordered rows by title. Without the title tiebreak the carousel order would
/// depend on whatever order the rows happened to come back from the server.
int _byAdminOrder(HomeSpecialRow a, HomeSpecialRow b) {
  final ao = a.sortOrder;
  final bo = b.sortOrder;
  if (ao != null && bo != null && ao != bo) return ao.compareTo(bo);
  if (ao != null && bo == null) return -1;
  if (ao == null && bo != null) return 1;
  return (a.title ?? '').toLowerCase().compareTo((b.title ?? '').toLowerCase());
}

/// The home "Specials" carousels, built from the admin's rows over the same
/// catalogue the rest of the home screen uses, so they always reflect what the
/// admin has published.
final homeSpecialsProvider = Provider<List<HomeSpecial>>((ref) {
  final tracks = ref.watch(homeTracksProvider).valueOrNull ?? const [];
  final playCounts = ref.watch(globalPlayCountsProvider).valueOrNull ?? const {};
  final rows = ref.watch(homeSpecialRowsProvider).valueOrNull ?? const [];
  return _buildSpecials(tracks, playCounts, rows);
});
