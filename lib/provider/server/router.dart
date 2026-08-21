import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sangeet/provider/server/routes/connect.dart';
import 'package:sangeet/provider/server/routes/playback.dart';
import 'package:sangeet/provider/server/routes/supabase_data.dart';

final serverRouterProvider = Provider((ref) {
  final playbackRoutes = ref.watch(serverPlaybackRoutesProvider);
  final connectRoutes = ref.watch(serverConnectRoutesProvider);
  final supabaseRoutes = ServerSupabaseDataRoutes(ref);

  final router = Router();

  router.get("/ping", (Request request) => Response.ok("pong"));

  // Playback proxy
  router.head("/stream/<trackId>", playbackRoutes.headStreamTrackId);
  router.get("/stream/<trackId>", playbackRoutes.getStreamTrackId);

  router.get("/playback/toggle-playback", playbackRoutes.togglePlayback);
  router.get("/playback/previous", playbackRoutes.previousTrack);
  router.get("/playback/next", playbackRoutes.nextTrack);

  // Supabase data endpoints
  router.get("/supabase/tracks", supabaseRoutes.getTracks);
  router.get("/supabase/tracks/<id>", supabaseRoutes.getTrack);
  router.get("/supabase/lyrics/<id>", supabaseRoutes.getLyrics);
  router.get("/supabase/search", supabaseRoutes.search);
  router.get("/supabase/admin-albums", supabaseRoutes.getAdminAlbums);
  router.get("/supabase/stream/<id>", supabaseRoutes.getStreamUrl);
  router.get("/supabase/browse/sections", supabaseRoutes.getBrowseSections);
  router.get("/supabase/browse/sections/<id>/items",
      supabaseRoutes.getBrowseSectionItems);
  router.get("/supabase/playlists/<id>", supabaseRoutes.getPlaylist);
  router.get(
      "/supabase/playlists/<id>/tracks", supabaseRoutes.getPlaylistTracks);
  router.get("/supabase/user-playlists", supabaseRoutes.getUserPlaylists);
  router.post("/supabase/api/playlists", supabaseRoutes.createUserPlaylist);
  router.post(
      "/supabase/api/playlists/<id>/songs", supabaseRoutes.addUserPlaylistSong);
  router.delete(
      "/supabase/api/playlists/<id>", supabaseRoutes.deleteUserPlaylist);
  router.delete("/supabase/api/playlists/<playlistId>/songs/<trackId>",
      supabaseRoutes.removeUserPlaylistSong);
  router.get("/supabase/artists", supabaseRoutes.getArtists);
  router.get("/supabase/albums", supabaseRoutes.getAlbums);
  router.get("/supabase/albums/<id>", supabaseRoutes.getAlbum);
  router.get("/supabase/albums/<id>/tracks", supabaseRoutes.getAlbumTracks);
  router.get("/supabase/artists/<id>", supabaseRoutes.getArtist);
  router.get(
      "/supabase/artists/<id>/top-tracks", supabaseRoutes.getArtistTopTracks);
  router.get("/supabase/users/me", supabaseRoutes.getUserMe);
  router.get("/supabase/liked-songs/supabase", supabaseRoutes.getLikedSongs);
  router.post("/supabase/liked-songs", supabaseRoutes.addLikedSong);
  router.delete(
      "/supabase/liked-songs/<trackId>", supabaseRoutes.removeLikedSong);

  // Global play tracking (Top Trending)
  router.post("/supabase/plays", supabaseRoutes.recordPlay);
  router.get("/supabase/plays/trending", supabaseRoutes.getPlayCounts);

  // Referral / affiliate program
  router.get(
      "/supabase/referrals/<userId>/code", supabaseRoutes.getReferralCode);
  router.post("/supabase/referrals/attribute",
      supabaseRoutes.recordReferralAttribution);
  router.get("/supabase/referrals/<userId>/summary",
      supabaseRoutes.getReferralSummary);

  // Coupon affiliate program (attribution-only codes)
  router.post("/supabase/coupons/validate", supabaseRoutes.validateCoupon);
  router.post("/supabase/coupons/redeem", supabaseRoutes.redeemCoupon);
  router.post("/supabase/referrers/bind", supabaseRoutes.bindReferrer);

  router.all("/ws", connectRoutes.websocket);

  return router;
});
