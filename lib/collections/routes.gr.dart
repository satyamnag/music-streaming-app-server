// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i35;
import 'package:flutter/material.dart' as _i36;
import 'package:sangeet/models/metadata/metadata.dart' as _i37;
import 'package:sangeet/pages/album/album.dart' as _i2;
import 'package:sangeet/pages/artist/artist.dart' as _i3;
import 'package:sangeet/pages/connect/connect.dart' as _i5;
import 'package:sangeet/pages/connect/control/control.dart' as _i4;
import 'package:sangeet/pages/home/home.dart' as _i7;
import 'package:sangeet/pages/home/home_see_all.dart' as _i8;
import 'package:sangeet/pages/home/sections/section_items.dart' as _i6;
import 'package:sangeet/pages/jaap/jaap_counter.dart' as _i9;
import 'package:sangeet/pages/library/library.dart' as _i10;
import 'package:sangeet/pages/library/user_artists.dart' as _i33;
import 'package:sangeet/pages/library/user_playlists.dart' as _i34;
import 'package:sangeet/pages/lyrics/lyrics.dart' as _i13;
import 'package:sangeet/pages/lyrics/mini_lyrics.dart' as _i14;
import 'package:sangeet/pages/player/lyrics.dart' as _i15;
import 'package:sangeet/pages/player/queue.dart' as _i16;
import 'package:sangeet/pages/player/sources.dart' as _i17;
import 'package:sangeet/pages/playlist/liked_playlist.dart' as _i11;
import 'package:sangeet/pages/playlist/playlist.dart' as _i18;
import 'package:sangeet/pages/profile/profile.dart' as _i19;
import 'package:sangeet/pages/recent/recently_played.dart' as _i20;
import 'package:sangeet/pages/root/root_app.dart' as _i21;
import 'package:sangeet/pages/search/search.dart' as _i22;
import 'package:sangeet/pages/settings/about.dart' as _i1;
import 'package:sangeet/pages/settings/logs.dart' as _i12;
import 'package:sangeet/pages/settings/metadata/metadata_form.dart' as _i23;
import 'package:sangeet/pages/settings/metadata_plugins.dart' as _i24;
import 'package:sangeet/pages/settings/settings.dart' as _i25;
import 'package:sangeet/pages/stats/artists/artists.dart' as _i26;
import 'package:sangeet/pages/stats/fees/fees.dart' as _i30;
import 'package:sangeet/pages/stats/minutes/minutes.dart' as _i27;
import 'package:sangeet/pages/stats/playlists/playlists.dart' as _i29;
import 'package:sangeet/pages/stats/stats.dart' as _i28;
import 'package:sangeet/pages/stats/streams/streams.dart' as _i31;
import 'package:sangeet/pages/track/track.dart' as _i32;
import 'package:shadcn_flutter/shadcn_flutter.dart' as _i38;

/// generated route for
/// [_i1.AboutSangeetPage]
class AboutSangeetRoute extends _i35.PageRouteInfo<void> {
  const AboutSangeetRoute({List<_i35.PageRouteInfo>? children})
    : super(AboutSangeetRoute.name, initialChildren: children);

  static const String name = 'AboutSangeetRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i1.AboutSangeetPage();
    },
  );
}

/// generated route for
/// [_i2.AlbumPage]
class AlbumRoute extends _i35.PageRouteInfo<AlbumRouteArgs> {
  AlbumRoute({
    _i36.Key? key,
    required String id,
    required _i37.SangeetSimpleAlbumObject album,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         AlbumRoute.name,
         args: AlbumRouteArgs(key: key, id: id, album: album),
         rawPathParams: {'id': id},
         initialChildren: children,
       );

  static const String name = 'AlbumRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AlbumRouteArgs>();
      return _i2.AlbumPage(key: args.key, id: args.id, album: args.album);
    },
  );
}

class AlbumRouteArgs {
  const AlbumRouteArgs({this.key, required this.id, required this.album});

  final _i36.Key? key;

  final String id;

  final _i37.SangeetSimpleAlbumObject album;

  @override
  String toString() {
    return 'AlbumRouteArgs{key: $key, id: $id, album: $album}';
  }
}

/// generated route for
/// [_i3.ArtistPage]
class ArtistRoute extends _i35.PageRouteInfo<ArtistRouteArgs> {
  ArtistRoute({
    required String artistId,
    _i36.Key? key,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         ArtistRoute.name,
         args: ArtistRouteArgs(artistId: artistId, key: key),
         rawPathParams: {'id': artistId},
         initialChildren: children,
       );

  static const String name = 'ArtistRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ArtistRouteArgs>(
        orElse: () => ArtistRouteArgs(artistId: pathParams.getString('id')),
      );
      return _i3.ArtistPage(args.artistId, key: args.key);
    },
  );
}

class ArtistRouteArgs {
  const ArtistRouteArgs({required this.artistId, this.key});

  final String artistId;

  final _i36.Key? key;

  @override
  String toString() {
    return 'ArtistRouteArgs{artistId: $artistId, key: $key}';
  }
}

/// generated route for
/// [_i4.ConnectControlPage]
class ConnectControlRoute extends _i35.PageRouteInfo<void> {
  const ConnectControlRoute({List<_i35.PageRouteInfo>? children})
    : super(ConnectControlRoute.name, initialChildren: children);

  static const String name = 'ConnectControlRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i4.ConnectControlPage();
    },
  );
}

/// generated route for
/// [_i5.ConnectPage]
class ConnectRoute extends _i35.PageRouteInfo<void> {
  const ConnectRoute({List<_i35.PageRouteInfo>? children})
    : super(ConnectRoute.name, initialChildren: children);

  static const String name = 'ConnectRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i5.ConnectPage();
    },
  );
}

/// generated route for
/// [_i6.HomeBrowseSectionItemsPage]
class HomeBrowseSectionItemsRoute
    extends _i35.PageRouteInfo<HomeBrowseSectionItemsRouteArgs> {
  HomeBrowseSectionItemsRoute({
    _i38.Key? key,
    required String sectionId,
    required _i37.SangeetBrowseSectionObject<Object> section,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         HomeBrowseSectionItemsRoute.name,
         args: HomeBrowseSectionItemsRouteArgs(
           key: key,
           sectionId: sectionId,
           section: section,
         ),
         rawPathParams: {'sectionId': sectionId},
         initialChildren: children,
       );

  static const String name = 'HomeBrowseSectionItemsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeBrowseSectionItemsRouteArgs>();
      return _i6.HomeBrowseSectionItemsPage(
        key: args.key,
        sectionId: args.sectionId,
        section: args.section,
      );
    },
  );
}

class HomeBrowseSectionItemsRouteArgs {
  const HomeBrowseSectionItemsRouteArgs({
    this.key,
    required this.sectionId,
    required this.section,
  });

  final _i38.Key? key;

  final String sectionId;

  final _i37.SangeetBrowseSectionObject<Object> section;

  @override
  String toString() {
    return 'HomeBrowseSectionItemsRouteArgs{key: $key, sectionId: $sectionId, section: $section}';
  }
}

/// generated route for
/// [_i7.HomePage]
class HomeRoute extends _i35.PageRouteInfo<void> {
  const HomeRoute({List<_i35.PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i7.HomePage();
    },
  );
}

/// generated route for
/// [_i8.HomeSeeAllPage]
class HomeSeeAllRoute extends _i35.PageRouteInfo<HomeSeeAllRouteArgs> {
  HomeSeeAllRoute({
    _i38.Key? key,
    required _i8.HomeSeeAllKind kind,
    String? language,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         HomeSeeAllRoute.name,
         args: HomeSeeAllRouteArgs(key: key, kind: kind, language: language),
         initialChildren: children,
       );

  static const String name = 'HomeSeeAllRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<HomeSeeAllRouteArgs>();
      return _i8.HomeSeeAllPage(
        key: args.key,
        kind: args.kind,
        language: args.language,
      );
    },
  );
}

class HomeSeeAllRouteArgs {
  const HomeSeeAllRouteArgs({this.key, required this.kind, this.language});

  final _i38.Key? key;

  final _i8.HomeSeeAllKind kind;

  final String? language;

  @override
  String toString() {
    return 'HomeSeeAllRouteArgs{key: $key, kind: $kind, language: $language}';
  }
}

/// generated route for
/// [_i9.JaapCounterPage]
class JaapCounterRoute extends _i35.PageRouteInfo<void> {
  const JaapCounterRoute({List<_i35.PageRouteInfo>? children})
    : super(JaapCounterRoute.name, initialChildren: children);

  static const String name = 'JaapCounterRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i9.JaapCounterPage();
    },
  );
}

/// generated route for
/// [_i10.LibraryPage]
class LibraryRoute extends _i35.PageRouteInfo<void> {
  const LibraryRoute({List<_i35.PageRouteInfo>? children})
    : super(LibraryRoute.name, initialChildren: children);

  static const String name = 'LibraryRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i10.LibraryPage();
    },
  );
}

/// generated route for
/// [_i11.LikedPlaylistPage]
class LikedPlaylistRoute extends _i35.PageRouteInfo<LikedPlaylistRouteArgs> {
  LikedPlaylistRoute({
    _i36.Key? key,
    required _i37.SangeetSimplePlaylistObject playlist,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         LikedPlaylistRoute.name,
         args: LikedPlaylistRouteArgs(key: key, playlist: playlist),
         initialChildren: children,
       );

  static const String name = 'LikedPlaylistRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LikedPlaylistRouteArgs>();
      return _i11.LikedPlaylistPage(key: args.key, playlist: args.playlist);
    },
  );
}

class LikedPlaylistRouteArgs {
  const LikedPlaylistRouteArgs({this.key, required this.playlist});

  final _i36.Key? key;

  final _i37.SangeetSimplePlaylistObject playlist;

  @override
  String toString() {
    return 'LikedPlaylistRouteArgs{key: $key, playlist: $playlist}';
  }
}

/// generated route for
/// [_i12.LogsPage]
class LogsRoute extends _i35.PageRouteInfo<void> {
  const LogsRoute({List<_i35.PageRouteInfo>? children})
    : super(LogsRoute.name, initialChildren: children);

  static const String name = 'LogsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i12.LogsPage();
    },
  );
}

/// generated route for
/// [_i13.LyricsPage]
class LyricsRoute extends _i35.PageRouteInfo<void> {
  const LyricsRoute({List<_i35.PageRouteInfo>? children})
    : super(LyricsRoute.name, initialChildren: children);

  static const String name = 'LyricsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i13.LyricsPage();
    },
  );
}

/// generated route for
/// [_i14.MiniLyricsPage]
class MiniLyricsRoute extends _i35.PageRouteInfo<MiniLyricsRouteArgs> {
  MiniLyricsRoute({
    _i38.Key? key,
    required _i38.Size prevSize,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         MiniLyricsRoute.name,
         args: MiniLyricsRouteArgs(key: key, prevSize: prevSize),
         initialChildren: children,
       );

  static const String name = 'MiniLyricsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MiniLyricsRouteArgs>();
      return _i14.MiniLyricsPage(key: args.key, prevSize: args.prevSize);
    },
  );
}

class MiniLyricsRouteArgs {
  const MiniLyricsRouteArgs({this.key, required this.prevSize});

  final _i38.Key? key;

  final _i38.Size prevSize;

  @override
  String toString() {
    return 'MiniLyricsRouteArgs{key: $key, prevSize: $prevSize}';
  }
}

/// generated route for
/// [_i15.PlayerLyricsPage]
class PlayerLyricsRoute extends _i35.PageRouteInfo<void> {
  const PlayerLyricsRoute({List<_i35.PageRouteInfo>? children})
    : super(PlayerLyricsRoute.name, initialChildren: children);

  static const String name = 'PlayerLyricsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i15.PlayerLyricsPage();
    },
  );
}

/// generated route for
/// [_i16.PlayerQueuePage]
class PlayerQueueRoute extends _i35.PageRouteInfo<void> {
  const PlayerQueueRoute({List<_i35.PageRouteInfo>? children})
    : super(PlayerQueueRoute.name, initialChildren: children);

  static const String name = 'PlayerQueueRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i16.PlayerQueuePage();
    },
  );
}

/// generated route for
/// [_i17.PlayerTrackSourcesPage]
class PlayerTrackSourcesRoute extends _i35.PageRouteInfo<void> {
  const PlayerTrackSourcesRoute({List<_i35.PageRouteInfo>? children})
    : super(PlayerTrackSourcesRoute.name, initialChildren: children);

  static const String name = 'PlayerTrackSourcesRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i17.PlayerTrackSourcesPage();
    },
  );
}

/// generated route for
/// [_i18.PlaylistPage]
class PlaylistRoute extends _i35.PageRouteInfo<PlaylistRouteArgs> {
  PlaylistRoute({
    _i36.Key? key,
    required String id,
    required _i37.SangeetSimplePlaylistObject playlist,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         PlaylistRoute.name,
         args: PlaylistRouteArgs(key: key, id: id, playlist: playlist),
         rawPathParams: {'id': id},
         initialChildren: children,
       );

  static const String name = 'PlaylistRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PlaylistRouteArgs>();
      return _i18.PlaylistPage(
        key: args.key,
        id: args.id,
        playlist: args.playlist,
      );
    },
  );
}

class PlaylistRouteArgs {
  const PlaylistRouteArgs({this.key, required this.id, required this.playlist});

  final _i36.Key? key;

  final String id;

  final _i37.SangeetSimplePlaylistObject playlist;

  @override
  String toString() {
    return 'PlaylistRouteArgs{key: $key, id: $id, playlist: $playlist}';
  }
}

/// generated route for
/// [_i19.ProfilePage]
class ProfileRoute extends _i35.PageRouteInfo<void> {
  const ProfileRoute({List<_i35.PageRouteInfo>? children})
    : super(ProfileRoute.name, initialChildren: children);

  static const String name = 'ProfileRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i19.ProfilePage();
    },
  );
}

/// generated route for
/// [_i20.RecentlyPlayedPage]
class RecentlyPlayedRoute extends _i35.PageRouteInfo<void> {
  const RecentlyPlayedRoute({List<_i35.PageRouteInfo>? children})
    : super(RecentlyPlayedRoute.name, initialChildren: children);

  static const String name = 'RecentlyPlayedRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i20.RecentlyPlayedPage();
    },
  );
}

/// generated route for
/// [_i21.RootAppPage]
class RootAppRoute extends _i35.PageRouteInfo<void> {
  const RootAppRoute({List<_i35.PageRouteInfo>? children})
    : super(RootAppRoute.name, initialChildren: children);

  static const String name = 'RootAppRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i21.RootAppPage();
    },
  );
}

/// generated route for
/// [_i22.SearchPage]
class SearchRoute extends _i35.PageRouteInfo<void> {
  const SearchRoute({List<_i35.PageRouteInfo>? children})
    : super(SearchRoute.name, initialChildren: children);

  static const String name = 'SearchRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i22.SearchPage();
    },
  );
}

/// generated route for
/// [_i23.SettingsMetadataProviderFormPage]
class SettingsMetadataProviderFormRoute
    extends _i35.PageRouteInfo<SettingsMetadataProviderFormRouteArgs> {
  SettingsMetadataProviderFormRoute({
    _i38.Key? key,
    required String title,
    required List<_i37.MetadataFormFieldObject> fields,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         SettingsMetadataProviderFormRoute.name,
         args: SettingsMetadataProviderFormRouteArgs(
           key: key,
           title: title,
           fields: fields,
         ),
         initialChildren: children,
       );

  static const String name = 'SettingsMetadataProviderFormRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingsMetadataProviderFormRouteArgs>();
      return _i23.SettingsMetadataProviderFormPage(
        key: args.key,
        title: args.title,
        fields: args.fields,
      );
    },
  );
}

class SettingsMetadataProviderFormRouteArgs {
  const SettingsMetadataProviderFormRouteArgs({
    this.key,
    required this.title,
    required this.fields,
  });

  final _i38.Key? key;

  final String title;

  final List<_i37.MetadataFormFieldObject> fields;

  @override
  String toString() {
    return 'SettingsMetadataProviderFormRouteArgs{key: $key, title: $title, fields: $fields}';
  }
}

/// generated route for
/// [_i24.SettingsMetadataProviderPage]
class SettingsMetadataProviderRoute extends _i35.PageRouteInfo<void> {
  const SettingsMetadataProviderRoute({List<_i35.PageRouteInfo>? children})
    : super(SettingsMetadataProviderRoute.name, initialChildren: children);

  static const String name = 'SettingsMetadataProviderRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i24.SettingsMetadataProviderPage();
    },
  );
}

/// generated route for
/// [_i25.SettingsPage]
class SettingsRoute extends _i35.PageRouteInfo<void> {
  const SettingsRoute({List<_i35.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i25.SettingsPage();
    },
  );
}

/// generated route for
/// [_i26.StatsArtistsPage]
class StatsArtistsRoute extends _i35.PageRouteInfo<void> {
  const StatsArtistsRoute({List<_i35.PageRouteInfo>? children})
    : super(StatsArtistsRoute.name, initialChildren: children);

  static const String name = 'StatsArtistsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i26.StatsArtistsPage();
    },
  );
}

/// generated route for
/// [_i27.StatsMinutesPage]
class StatsMinutesRoute extends _i35.PageRouteInfo<void> {
  const StatsMinutesRoute({List<_i35.PageRouteInfo>? children})
    : super(StatsMinutesRoute.name, initialChildren: children);

  static const String name = 'StatsMinutesRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i27.StatsMinutesPage();
    },
  );
}

/// generated route for
/// [_i28.StatsPage]
class StatsRoute extends _i35.PageRouteInfo<void> {
  const StatsRoute({List<_i35.PageRouteInfo>? children})
    : super(StatsRoute.name, initialChildren: children);

  static const String name = 'StatsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i28.StatsPage();
    },
  );
}

/// generated route for
/// [_i29.StatsPlaylistsPage]
class StatsPlaylistsRoute extends _i35.PageRouteInfo<void> {
  const StatsPlaylistsRoute({List<_i35.PageRouteInfo>? children})
    : super(StatsPlaylistsRoute.name, initialChildren: children);

  static const String name = 'StatsPlaylistsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i29.StatsPlaylistsPage();
    },
  );
}

/// generated route for
/// [_i30.StatsStreamFeesPage]
class StatsStreamFeesRoute extends _i35.PageRouteInfo<void> {
  const StatsStreamFeesRoute({List<_i35.PageRouteInfo>? children})
    : super(StatsStreamFeesRoute.name, initialChildren: children);

  static const String name = 'StatsStreamFeesRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i30.StatsStreamFeesPage();
    },
  );
}

/// generated route for
/// [_i31.StatsStreamsPage]
class StatsStreamsRoute extends _i35.PageRouteInfo<void> {
  const StatsStreamsRoute({List<_i35.PageRouteInfo>? children})
    : super(StatsStreamsRoute.name, initialChildren: children);

  static const String name = 'StatsStreamsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i31.StatsStreamsPage();
    },
  );
}

/// generated route for
/// [_i32.TrackPage]
class TrackRoute extends _i35.PageRouteInfo<TrackRouteArgs> {
  TrackRoute({
    _i38.Key? key,
    required String trackId,
    List<_i35.PageRouteInfo>? children,
  }) : super(
         TrackRoute.name,
         args: TrackRouteArgs(key: key, trackId: trackId),
         rawPathParams: {'id': trackId},
         initialChildren: children,
       );

  static const String name = 'TrackRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<TrackRouteArgs>(
        orElse: () => TrackRouteArgs(trackId: pathParams.getString('id')),
      );
      return _i32.TrackPage(key: args.key, trackId: args.trackId);
    },
  );
}

class TrackRouteArgs {
  const TrackRouteArgs({this.key, required this.trackId});

  final _i38.Key? key;

  final String trackId;

  @override
  String toString() {
    return 'TrackRouteArgs{key: $key, trackId: $trackId}';
  }
}

/// generated route for
/// [_i33.UserArtistsPage]
class UserArtistsRoute extends _i35.PageRouteInfo<void> {
  const UserArtistsRoute({List<_i35.PageRouteInfo>? children})
    : super(UserArtistsRoute.name, initialChildren: children);

  static const String name = 'UserArtistsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i33.UserArtistsPage();
    },
  );
}

/// generated route for
/// [_i34.UserPlaylistsPage]
class UserPlaylistsRoute extends _i35.PageRouteInfo<void> {
  const UserPlaylistsRoute({List<_i35.PageRouteInfo>? children})
    : super(UserPlaylistsRoute.name, initialChildren: children);

  static const String name = 'UserPlaylistsRoute';

  static _i35.PageInfo page = _i35.PageInfo(
    name,
    builder: (data) {
      return const _i34.UserPlaylistsPage();
    },
  );
}
