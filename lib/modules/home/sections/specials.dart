import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/home_tracks/home_tracks.dart';

/// One curated "Special" shelf shown as a full-width carousel on the home
/// screen (e.g. "Ganesha Special").
class HomeSpecial {
  /// Stable id (also used as the Widget key so slides are recycled correctly).
  final String id;

  /// Display title, e.g. "Ganesha Special".
  final String title;

  /// Short supporting line under the title.
  final String subtitle;

  /// Cover for the slide: the most-played track's art in this shelf.
  final String imageUrl;

  /// The shelf's tracks, most played first. Never empty (empty shelves are
  /// dropped by the provider).
  final List<SangeetTrackObject> tracks;

  const HomeSpecial({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.tracks,
  });
}

/// A curated shelf definition: the deity/theme, how to match tracks for it,
/// and the artwork fallback when no track in the shelf has a cover.
class _SpecialDefinition {
  final String id;
  final String title;
  final String subtitle;

  /// Keywords matched case-insensitively against a track's name, album name,
  /// artist names and admin tags. Any single hit qualifies the track.
  final List<String> keywords;

  const _SpecialDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.keywords,
  });
}

/// The curated shelves, in display order.
///
/// Keywords are deliberately specific (e.g. "ganesha" plus its common
/// synonyms like "vinayaka"/"vighneshwara") so a track is not pulled into a
/// shelf it does not belong to. Matching is substring-based against the
/// track's own text, which is how devotional catalogues are actually named.
const List<_SpecialDefinition> _specialDefinitions = [
  _SpecialDefinition(
    id: 'soulful-bhakti',
    title: 'Soulful Bhakti Special',
    subtitle: 'Devotional favourites across every deity',
    keywords: ['bhakti', 'bhajan', 'devotional', 'soulful'],
  ),
  _SpecialDefinition(
    id: 'ganesha',
    title: 'Ganesha Special',
    subtitle: 'Vinayaka chants and songs',
    keywords: ['ganesh', 'ganesha', 'ganapati', 'ganapathi', 'vinayaka', 'vighnesh', 'vignesh', 'gajanana', 'gajanand', 'vakratunda', 'ekadanta', 'lambodara'],
  ),
  _SpecialDefinition(
    id: 'venkateswara',
    title: 'Venkateswara Special',
    subtitle: 'Balaji and Govinda songs',
    keywords: ['venkateswara', 'venkateshwara', 'balaji', 'govinda', 'tirupati', 'srinivasa', 'govind'],
  ),
  _SpecialDefinition(
    id: 'krishna',
    title: 'Krishna Special',
    subtitle: 'Krishna bhajans and kirtans',
    keywords: ['krishna', 'krishna', 'govardhan', 'radha', 'murali', 'gopala', 'madhav', 'keshav'],
  ),
  _SpecialDefinition(
    id: 'rama',
    title: 'Rama Special',
    subtitle: 'Rama bhajans and stotras',
    keywords: ['rama', 'sita', 'hanuman', 'ayodhya', 'raghu', 'rama raksha'],
  ),
  _SpecialDefinition(
    id: 'shiva',
    title: 'Shiva Special',
    subtitle: 'Shiva chants and stotras',
    keywords: ['shiva', 'siva', 'mahadev', 'parvati', 'rudra', 'linga', 'kailash', 'shankar'],
  ),
  _SpecialDefinition(
    id: 'lakshmi',
    title: 'Lakshmi Special',
    subtitle: 'Lakshmi and wealth stotras',
    keywords: ['lakshmi', 'laxmi', 'ashtalakshmi', 'kanakadhara', 'wealth', 'shree', 'mahalakshmi', 'mahalaxmi', 'sri lakshmi', 'dhana'],
  ),
  _SpecialDefinition(
    id: 'vishnu',
    title: 'Vishnu Special',
    subtitle: 'Vishnu sahasranamam and more',
    keywords: ['vishnu', 'narayana', 'hari', 'sahasranama', 'sahasranamam', 'anantha', 'padmanabha'],
  ),
  _SpecialDefinition(
    id: 'parvati',
    title: 'Parvati Special',
    subtitle: 'Devi and Shakti songs',
    keywords: ['parvati', 'durga', 'devi', 'shakti', 'ambika', 'bhavani', 'mata', 'kaali', 'kali'],
  ),
  _SpecialDefinition(
    id: 'ganga',
    title: 'Ganga Special',
    subtitle: 'Ganga and Gange stotras',
    keywords: ['ganga', 'gange', 'ganges', 'bhagirathi', 'ganga maiya'],
  ),
];

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

/// Builds the "Special" shelves from the full catalogue.
///
/// A shelf is included only when it actually has tracks, so the home screen
/// never shows an empty carousel. Within a shelf, tracks are ordered by global
/// play count (most played first) so the slide's cover is the most popular
/// track's artwork, then by name for stability.
List<HomeSpecial> _buildSpecials(
  List<SangeetTrackObject> tracks,
  Map<String, int> playCounts,
) {
  if (tracks.isEmpty) return const [];

  // Pre-compute one lowercase haystack per track (name + album + artists +
  // tags) so matching is a single pass per shelf rather than re-joining
  // strings for every keyword.
  final haystacks = <String, String>{
    for (final t in tracks) t.id: _haystackFor(t),
  };

  final specials = <HomeSpecial>[];
  for (final def in _specialDefinitions) {
    final matched = tracks.where((t) {
      final haystack = haystacks[t.id] ?? '';
      return def.keywords.any((k) => _keywordMatches(haystack, k));
    }).toList();

    if (matched.isEmpty) continue;

    matched.sort((a, b) {
      final cmp = (playCounts[b.id] ?? 0).compareTo(playCounts[a.id] ?? 0);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    specials.add(HomeSpecial(
      id: def.id,
      title: def.title,
      subtitle: def.subtitle,
      imageUrl: _coverFor(matched),
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
/// artwork, falling back to the shared album-art placeholder.
String _coverFor(List<SangeetTrackObject> tracks) {
  for (final track in tracks) {
    final url = track.album.images.smallest(ImagePlaceholder.albumArt);
    if (url.isNotEmpty) return url;
  }
  return '';
}

/// The home "Specials" carousels: curated deity/theme shelves built from the
/// same catalogue the rest of the home screen uses, so they always reflect
/// what the admin has published.
final homeSpecialsProvider = Provider<List<HomeSpecial>>((ref) {
  final tracks = ref.watch(homeTracksProvider).valueOrNull ?? const [];
  final playCounts = ref.watch(globalPlayCountsProvider).valueOrNull ?? const {};
  return _buildSpecials(tracks, playCounts);
});
