import 'package:drift/native.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('foreign key enforcement is enabled on open', () async {
    final row = await db.customSelect('PRAGMA foreign_keys;').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  test('deleting a counter cascades to its daily rows', () async {
    final counterId = await db.into(db.jaapCountersTable).insert(
          JaapCountersTableCompanion.insert(name: 'Gayatri'),
        );
    await db.into(db.jaapDailyCountsTable).insert(
          JaapDailyCountsTableCompanion.insert(
            counterId: counterId,
            day: '2025-09-20',
          ),
        );

    expect(await db.select(db.jaapDailyCountsTable).get(), hasLength(1));

    await (db.delete(db.jaapCountersTable)
          ..where((t) => t.id.equals(counterId)))
        .go();

    expect(await db.select(db.jaapDailyCountsTable).get(), isEmpty);
  });

  test('a daily row referencing a missing counter is rejected', () async {
    await expectLater(
      db.into(db.jaapDailyCountsTable).insert(
            JaapDailyCountsTableCompanion.insert(
              counterId: 999,
              day: '2025-09-20',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('deleting a playlist cascades to its songs', () async {
    await db.into(db.localPlaylistsTable).insert(
          LocalPlaylistsTableCompanion.insert(id: 'p1', name: 'Bhajans'),
        );
    await db.into(db.localPlaylistSongsTable).insert(
          LocalPlaylistSongsTableCompanion.insert(
            playlistId: 'p1',
            trackId: 't1',
          ),
        );

    expect(await db.select(db.localPlaylistSongsTable).get(), hasLength(1));

    await (db.delete(db.localPlaylistsTable)
          ..where((t) => t.id.equals('p1')))
        .go();

    expect(await db.select(db.localPlaylistSongsTable).get(), isEmpty);
  });

  test('a song referencing a missing playlist is rejected', () async {
    await expectLater(
      db.into(db.localPlaylistSongsTable).insert(
            LocalPlaylistSongsTableCompanion.insert(
              playlistId: 'missing',
              trackId: 't1',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('account-deletion cleanup order empties playlists and their songs',
      () async {
    await db.into(db.localPlaylistsTable).insert(
          LocalPlaylistsTableCompanion.insert(id: 'p1', name: 'Bhajans'),
        );
    await db.into(db.localPlaylistSongsTable).insert(
          LocalPlaylistSongsTableCompanion.insert(
            playlistId: 'p1',
            trackId: 't1',
          ),
        );
    await db.into(db.localPlaylistSongsTable).insert(
          LocalPlaylistSongsTableCompanion.insert(
            playlistId: 'p1',
            trackId: 't2',
          ),
        );

    expect(await db.select(db.localPlaylistSongsTable).get(), hasLength(2));

    // Same order as clerk_auth_provider.dart deleteAccount(): children first,
    // then parents.
    await db.delete(db.localPlaylistSongsTable).go();
    await db.delete(db.localPlaylistsTable).go();

    expect(await db.select(db.localPlaylistSongsTable).get(), isEmpty);
    expect(await db.select(db.localPlaylistsTable).get(), isEmpty);
  });

  test('v13 -> v14 migration repairs the local playlist foreign key', () async {
    final raw = sqlite3.openInMemory();
    // Pre-v14 schema: local_playlists_table.id is not a primary key and
    // local_playlist_songs_table.playlist_id has no ON DELETE action.
    raw.execute('''
      CREATE TABLE local_playlists_table (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
      );
    ''');
    raw.execute('''
      CREATE TABLE local_playlist_songs_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT NOT NULL REFERENCES local_playlists_table (id),
        track_id TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute(
        "INSERT INTO local_playlists_table (id, name) VALUES ('p1', 'Bhajans')");
    raw.execute(
        "INSERT INTO local_playlist_songs_table (playlist_id, track_id) VALUES ('p1', 't1')");
    raw.userVersion = 13;

    final migrated = AppDatabase.forTesting(NativeDatabase.opened(raw));
    // Trigger the lazy open so onUpgrade(13 -> 14) runs.
    await migrated.customSelect('SELECT 1').getSingle();

    // Existing rows survived the table recreation.
    expect(
      (await migrated.select(migrated.localPlaylistsTable).get())
          .map((p) => p.id),
      contains('p1'),
    );
    expect(
      (await migrated.select(migrated.localPlaylistSongsTable).get())
          .map((s) => s.trackId),
      contains('t1'),
    );

    // The FK is now valid and cascades.
    await (migrated.delete(migrated.localPlaylistsTable)
          ..where((t) => t.id.equals('p1')))
        .go();
    expect(await migrated.select(migrated.localPlaylistSongsTable).get(),
        isEmpty);

    await migrated.close();
  });
}
