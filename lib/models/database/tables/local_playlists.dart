part of '../database.dart';

/// User-created playlists stored on-device.
///
/// The app cannot persist user playlists to Supabase (RLS blocks anonymous
/// writes), so user-made playlists live in the local drift database. They are
/// served to the UI through the local stream server.
class LocalPlaylistsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Tracks belonging to a user-created local playlist.
class LocalPlaylistSongsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(LocalPlaylistsTable, #id)();
  TextColumn get trackId => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}
