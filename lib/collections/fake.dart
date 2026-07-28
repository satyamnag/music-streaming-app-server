import 'package:sangeet/models/database/database.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/provider/history/summary.dart';

abstract class FakeData {
  static final SangeetImageObject image = SangeetImageObject(
    height: 100,
    width: 100,
    url: "https://dummyimage.com/100x100/cfcfcf/cfcfcf.jpg",
  );

  static final SangeetFullArtistObject artist = SangeetFullArtistObject(
    id: "1",
    name: "What an artist",
    externalUri: "https://example.com",
    followers: 10000,
    genres: ["genre"],
    images: [
      SangeetImageObject(
        height: 100,
        width: 100,
        url: "https://dummyimage.com/100x100/cfcfcf/cfcfcf.jpg",
      ),
    ],
  );

  static final SangeetFullAlbumObject album = SangeetFullAlbumObject(
    id: "1",
    name: "A good album",
    externalUri: "https://example.com",
    artists: [artistSimple],
    releaseDate: "2021-01-01",
    albumType: SangeetAlbumType.album,
    images: [image],
    totalTracks: 10,
    genres: ["genre"],
    recordLabel: "Record Label",
  );

  static final SangeetSimpleArtistObject artistSimple =
      SangeetSimpleArtistObject(
    id: "1",
    name: "What an artist",
    externalUri: "https://example.com",
    images: null,
  );

  static final SangeetSimpleAlbumObject albumSimple = SangeetSimpleAlbumObject(
    albumType: SangeetAlbumType.album,
    artists: [],
    externalUri: "https://example.com",
    id: "1",
    name: "A good album",
    releaseDate: "2021-01-01",
    images: [
      SangeetImageObject(
        height: 1,
        width: 1,
        url: "https://dummyimage.com/100x100/cfcfcf/cfcfcf.jpg",
      )
    ],
  );

  static final SangeetFullTrackObject track = SangeetTrackObject.full(
    id: "1",
    name: "A good track",
    externalUri: "https://example.com",
    album: albumSimple,
    durationMs: 3 * 60 * 1000, // 3 minutes
    isrc: "USUM72112345",
    explicit: false,
  ) as SangeetFullTrackObject;

  static final SangeetUserObject user = SangeetUserObject(
    id: "1",
    name: "User Name",
    externalUri: "https://example.com",
    images: [image],
  );

  static final SangeetFullPlaylistObject playlist = SangeetFullPlaylistObject(
      id: "1",
      name: "A good playlist",
      description: "A very good playlist description",
      externalUri: "https://example.com",
      collaborative: false,
      public: true,
      owner: user,
      images: [image],
      collaborators: [user]);

  static final SangeetSimplePlaylistObject playlistSimple =
      SangeetSimplePlaylistObject(
    id: "1",
    name: "A good playlist",
    description: "A very good playlist description",
    externalUri: "https://example.com",
    owner: user,
    images: [image],
  );

  static final SangeetBrowseSectionObject browseSection =
      SangeetBrowseSectionObject(
          id: "section-id",
          title: "Browse Section",
          browseMore: true,
          externalUri: "https://example.com/browse/section",
          items: [playlistSimple, playlistSimple, playlistSimple]);

  static const historySummary = PlaybackHistorySummary(
    albums: 1,
    artists: 1,
    duration: Duration(seconds: 1),
    playlists: 1,
    tracks: 1,
    fees: 1,
  );

  static final historyRecentlyPlayedPlaylist = HistoryTableData(
    id: 0,
    type: HistoryEntryType.track,
    createdAt: DateTime.now(),
    itemId: "1",
    data: playlist.toJson(),
  );

  static final historyRecentlyPlayedAlbum = HistoryTableData(
    id: 0,
    type: HistoryEntryType.track,
    createdAt: DateTime.now(),
    itemId: "1",
    data: album.toJson(),
  );

  static final historyRecentlyPlayedItems = List.generate(
    10,
    (index) => index % 2 == 0
        ? historyRecentlyPlayedPlaylist
        : historyRecentlyPlayedAlbum,
  );
}
