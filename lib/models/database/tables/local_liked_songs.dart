part of '../database.dart';

/// Tracks the user liked on this device.
///
/// Like the local playlists, likes are stored on-device so the app works
/// without a Supabase account (RLS blocks anonymous writes). They are served
/// to the UI through the local stream server.
class LocalLikedSongsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
