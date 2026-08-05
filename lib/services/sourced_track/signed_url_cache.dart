/// In-memory TTL cache for Supabase storage signed URLs.
///
/// Signed URLs are valid for 3600 seconds, so resolving the same track
/// repeatedly (visible-track preload, stream proxy, playback resolver) should
/// reuse the already-issued URL instead of making a fresh Supabase API call
/// every time. This removes the createSignedUrl round-trip from the play path,
/// which is one of the main reasons a tap-to-play can feel slow.
class SignedUrlCache {
  SignedUrlCache._();

  static final SignedUrlCache instance = SignedUrlCache._();

  static const Duration _ttl = Duration(minutes: 55);

  final Map<String, _Entry> _entries = {};

  String? get(String storagePath) {
    final entry = _entries[storagePath];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.createdAt) > _ttl) {
      _entries.remove(storagePath);
      return null;
    }
    return entry.url;
  }

  void put(String storagePath, String url) {
    _entries[storagePath] = _Entry(url);
  }
}

class _Entry {
  final String url;
  final DateTime createdAt;

  _Entry(this.url) : createdAt = DateTime.now();
}
