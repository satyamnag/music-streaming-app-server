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

  // `id` must be the primary key: LocalPlaylistSongsTable.playlistId references
  // it, and SQLite only accepts a foreign key whose parent column is a primary
  // key or has a unique index. Without this the reference is an invalid foreign
  // key and, with `PRAGMA foreign_keys = ON`, every write to
  // local_playlist_songs_table fails with "foreign key mismatch".
  @override
  Set<Column> get primaryKey => {id};
}

/// Tracks belonging to a user-created local playlist.
class LocalPlaylistSongsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(
        LocalPlaylistsTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get trackId => text()();
  IntColumn get position => integer().withDefault(const Constant(0))();
}
