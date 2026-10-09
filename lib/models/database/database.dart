library database;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/remote.dart';
import 'package:encrypt/encrypt.dart';
import 'package:sangeet/services/audio_player/playlist_mode.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeMode;
import 'package:sangeet/models/database/database.steps.dart';
import 'package:sangeet/models/lyrics.dart';
import 'package:sangeet/models/metadata/market.dart';
import 'package:sangeet/models/metadata/metadata.dart';
import 'package:sangeet/services/kv_store/encrypted_kv_store.dart';
import 'package:sangeet/services/kv_store/kv_store.dart';
import 'package:flutter/widgets.dart' hide Table, Key, View, Column;
import 'package:sangeet/modules/settings/color_scheme_picker_dialog.dart';
import 'package:drift/native.dart';
import 'package:sangeet/services/logger/logger.dart';
import 'package:sangeet/services/youtube_engine/newpipe_engine.dart';
import 'package:sangeet/services/youtube_engine/youtube_explode_engine.dart';
import 'package:sangeet/services/youtube_engine/yt_dlp_engine.dart';
import 'package:sangeet/utils/platform.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

part 'tables/preferences.dart';
part 'tables/skip_segment.dart';
part 'tables/source_match.dart';
part 'tables/audio_player_state.dart';
part 'tables/history.dart';
part 'tables/lyrics.dart';
part 'tables/metadata_plugins.dart';
part 'tables/local_playlists.dart';
part 'tables/local_liked_songs.dart';

part 'typeconverters/color.dart';
part 'typeconverters/locale.dart';
part 'typeconverters/string_list.dart';
part 'typeconverters/encrypted_text.dart';
part 'typeconverters/map.dart';
part 'typeconverters/map_list.dart';
part 'typeconverters/subtitle.dart';

@DriftDatabase(
  tables: [
    PreferencesTable,
    SkipSegmentTable,
    SourceMatchTable,
    AudioPlayerStateTable,
    HistoryTable,
    LyricsTable,
    PluginsTable,
    LocalPlaylistsTable,
    LocalPlaylistSongsTable,
    LocalLikedSongsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// A database backed by a caller-provided executor, used by tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        // sqlite3 leaves foreign key enforcement off by default, which would
        // make ON DELETE CASCADE (e.g. local_playlist_songs_table.playlist_id)
        // inert. Enable it for every connection.
        await customStatement('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (m, from, to) async {
        // Run the existing step-by-step chain (up to v11). This must be capped
        // at 11 because the generated database.steps.dart does not yet carry a
        // from11To12 step; the v11 -> v12 change is applied below.
        if (from < 12) {
          final stepUpgrade = stepByStep(
            from1To2: (m, schema) async {
              // Add invidiousInstance column to preferences table
              await _addColumnIfMissing(
                m,
                schema.preferencesTable,
                schema.preferencesTable.invidiousInstance,
              );
            },
        from2To3: (m, schema) async {
          await _addColumnIfMissing(
            m,
            schema.preferencesTable,
            schema.preferencesTable.cacheMusic,
          );
        },
        from3To4: (m, schema) async {
          await _addColumnIfMissing(
            m,
            schema.preferencesTable,
            schema.preferencesTable.youtubeClientEngine,
          );
        },
        from4To5: (m, schema) async {
          final columnName = schema.preferencesTable.accentColorScheme
              .escapedNameFor(SqlDialect.sqlite);
          final columnNameOld =
              '"${schema.preferencesTable.accentColorScheme.name}_old"';
          final tableName = schema.preferencesTable.actualTableName;
          await customStatement(
            "ALTER TABLE $tableName "
            "RENAME COLUMN $columnName to $columnNameOld",
          );
          await customStatement(
            "ALTER TABLE $tableName "
            "ADD COLUMN $columnName TEXT NOT NULL DEFAULT 'Slate:0xff64748b'",
          );
          await customStatement(
            "UPDATE $tableName "
            "SET $columnName = $columnNameOld",
          );
          await customStatement(
            "ALTER TABLE $tableName "
            "DROP COLUMN $columnNameOld",
          );
          await customStatement(
            "UPDATE $tableName "
            "SET $columnName = 'Slate:0xff64748b' WHERE $columnName = 'Blue:0xFF2196F3'",
          );
        },
        from5To6: (m, schema) async {
          try {
            await m.addColumn(
              schema.preferencesTable,
              schema.preferencesTable.connectPort,
            );
          } on DriftRemoteException catch (e) {
            // If the column already exists, ignore the error
            if (e.remoteCause !=
                'duplicate column name: ${schema.preferencesTable.connectPort.name}') {
              rethrow;
            }
          }
        },
        from6To7: (m, schema) async {
          await m.createTable(schema.metadataPluginsTable);
          await m.addColumn(
            schema.audioPlayerStateTable,
            schema.audioPlayerStateTable.currentIndex,
          );
          await m.addColumn(
            schema.audioPlayerStateTable,
            schema.audioPlayerStateTable.tracks,
          );
        },
        from7To8: (m, schema) async {
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.entryPoint,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.apis,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.abilities,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.repository,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
          await m
              .addColumn(
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.pluginApiVersion,
          )
              .catchError((error, stackTrace) {
            // If the column already exists, ignore the error
            if (!error.toString().contains('duplicate column name')) {
              throw error;
            }
          });
        },
        from8To9: (m, schema) async {
          await m
              .renameTable(schema.pluginsTable, "metadata_plugins_table")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .renameColumn(
                schema.pluginsTable,
                "selected",
                pluginsTable.selectedForMetadata,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .addColumn(
                schema.pluginsTable,
                pluginsTable.selectedForAudioSource,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
        },
        from9To10: (m, schema) async {
          await m
              .dropColumn(schema.preferencesTable, "piped_instance")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .dropColumn(schema.preferencesTable, "invidious_instance")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .addColumn(
                schema.sourceMatchTable,
                sourceMatchTable.sourceInfo,
              )
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await customStatement("DROP INDEX IF EXISTS uniq_track_match;")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .dropColumn(schema.sourceMatchTable, "source_id")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
        },
        from10To11: (m, schema) async {
          // Local user-made playlists (Supabase RLS blocks anonymous writes,
          // so user playlists are stored on-device).
          await m.createTable(schema.localPlaylistsTable);
          await m.createTable(schema.localPlaylistSongsTable);
        },
          );
          await stepUpgrade(m, from, to > 11 ? 11 : to);
        }
        // v11 -> v12: local liked songs (device-local, no Supabase account).
        if (to >= 12 && from < 12) {
          await m.createTable(localLikedSongsTable);
        }
        // v13 -> v14: repair the local playlist foreign key. local_playlists_table
        // had no primary key, so local_playlist_songs_table.playlist_id pointed at
        // a non-unique column. With `PRAGMA foreign_keys = ON` that is an invalid
        // foreign key and SQLite rejects writes with "foreign key mismatch".
        // Recreate both tables: id becomes the primary key and playlist_id now
        // cascades on delete. `alterTable` preserves the existing rows.
        if (to >= 14 && from < 14) {
          await m.alterTable(TableMigration(localPlaylistsTable));
          await m.alterTable(TableMigration(localPlaylistSongsTable));
        }
        // v14 -> v15: the Jaap Counter feature was removed. Drop the local
        // counters and per-day counts tables. IF EXISTS keeps this a no-op for
        // installs that never created them (fresh databases, or upgrades that
        // skipped the jaap era entirely).
        if (to >= 15 && from < 15) {
          await customStatement('DROP TABLE IF EXISTS jaap_counters_table');
          await customStatement('DROP TABLE IF EXISTS jaap_daily_counts_table');
        }

        // Reconcile `preferences_table` with the table definition the shipping app
        // uses: rename the audio-source column, then rebuild so the columns' SQL
        // DEFAULTS match a fresh install.
        //
        // ## Two defects this fixes, both found by the migration test
        // Neither had ever been reported, because test/drift/app_db/migration_test.dart
        // could not compile and therefore never ran a single hop.
        //
        // 1. `audio_source` was renamed to `audio_source_id` at v10 in the table
        //    definition, but no migration performs the rename. The v9->v10 step only
        //    drops `piped_instance`/`invidious_instance` and edits `source_match`, so
        //    a database created before v10 simply does not have the column:
        //
        //        no such column: "audio_source_id"
        //
        //    `renameColumn` brings it across with its values intact, and is a no-op
        //    on databases that already have the new name (guarded below).
        //
        // 2. Three column DEFAULTS were changed in the table definition around v11,
        //    which is what a FRESH install gets:
        //
        //        accent_color_scheme   'Slate:0xff64748b'  ->  'maroon:0xff520101'
        //        market                'US'                ->  'IN'
        //        connect_port          -1                  ->  19876
        //
        //    Nothing ever changed them for databases that already existed. SQLite
        //    cannot ALTER a DEFAULT in place, so an old install kept the old default
        //    forever while a fresh install got the new one - two users on the same
        //    app version with differently-defaulted databases.
        //
        // ## Why the order matters, and why the rename is guarded twice
        // `m.renameColumn` throws if the source column is absent, and `TableMigration`
        // rebuilds the table by copying EVERY column of the current definition by
        // name - so it must run only once the table actually has them all. Both are
        // therefore done here, after `from1To2`..`from10To11` have normalised the
        // shape.
        //
        // The rename is also bounded to `to >= 10`, the version that introduced the
        // new name. A migration run to an INTERMEDIATE version - which
        // `testWithDataIntegrity(oldVersion: 1, newVersion: 2, ...)` legitimately
        // does - must leave the column as that version's snapshot describes it, so
        // an unbounded rename would make that test report a schema it is right to
        // expect.
        if (to >= 10) {
          final preferencesColumns =
              await customSelect('PRAGMA table_info(preferences_table)').get();
          final hasLegacyAudioSource = preferencesColumns
              .any((row) => row.read<String>('name') == 'audio_source');
          if (hasLegacyAudioSource) {
            await m.renameColumn(
              preferencesTable,
              'audio_source',
              preferencesTable.audioSourceId,
            );
          }
        }

        // Only `preferences_table` is rebuilt: it is the table whose defaults
        // drifted and it holds a single row, so the rebuild is cheap and
        // `TableMigration` preserves that row's values.
        //
        // Guarded on the table already having EVERY column the current definition
        // declares. `TableMigration` rebuilds by copying each current column BY
        // NAME, so on a database that has not yet been through all the
        // add/drop-column steps it would reference columns that do not exist:
        //
        //     no such column: "youtube_client_engine"
        //
        // That happens when a migration is run to an INTERMEDIATE version - which
        // `testWithDataIntegrity(oldVersion: 1, newVersion: 2, ...)` legitimately
        // does. The rebuild is a reconciliation to the CURRENT shape, so it is
        // simply not applicable to a database that stopped part-way; skipping it
        // there keeps that test meaningful and changes nothing for real upgrades,
        // which always run to the current version.
        if (await _hasAllColumns('preferences_table', preferencesTable)) {
          await m.alterTable(TableMigration(preferencesTable));
        }

        // Same class of defect on `source_match_table`: its `source_type` column
        // carried `DEFAULT 'youtube'` up to v9, and the default was REMOVED from
        // the table definition at v10 (`text()()`), but no migration ever dropped
        // it. A database created before v10 therefore keeps a default the current
        // schema does not declare.
        //
        // The column list here is unchanged between v9 and v15, so the rebuild is
        // safe from any starting version. `TableMigration` preserves the rows.
        if (await _hasAllColumns('source_match_table', sourceMatchTable)) {
          await m.alterTable(TableMigration(sourceMatchTable));
        }

        // And on the plugins table, in the opposite direction: `plugin_api_version`
        // picked up `DEFAULT '2.0.0'` at v9, but no migration added it, so a
        // database created earlier keeps the column with no default at all.
        //
        // `from8To9` only renames the TABLE (`metadata_plugins_table` ->
        // `plugins_table`) and two of its columns; the new default was never
        // applied. The rebuild here replaces the stored definition with the
        // current one, and `TableMigration` preserves the plugin rows.
        if (await _hasAllColumns('plugins_table', pluginsTable)) {
          await m.alterTable(TableMigration(pluginsTable));
        }
      },
    );
  }

  /// Whether [table] exists AND already carries every column [definition]
  /// declares.
  ///
  /// Used to decide whether a `TableMigration` rebuild can run: the rebuild copies
  /// the current columns BY NAME, so it is only valid once the table has all of
  /// them. Reading `PRAGMA table_info` is the cheap, non-destructive way to ask.
  Future<bool> _hasAllColumns(String table, TableInfo<Table, dynamic> definition) async {
    final rows = await customSelect("PRAGMA table_info($table)").get();
    if (rows.isEmpty) return false;
    final present = rows.map((row) => row.read<String>('name')).toSet();
    final expected = definition.$columns.map((column) => column.name);
    return expected.every(present.contains);
  }

  /// Adds [column] to [table] only when it is not already there.
  ///
  /// ## Why the step chain must be idempotent
  /// `m.addColumn` issues a bare `ALTER TABLE ... ADD COLUMN`. On SQLite that
  /// fails when the column already exists, and the failure is not always the
  /// explicit "duplicate column name" - an older SQLite reports a bare
  /// "SQL logic error (code 1)" instead.
  ///
  /// That difference is real and was observed: every migration hop from v1..v8
  /// passed on a local SQLite 3.50.4 and FAILED on the CI runner's older build
  /// with
  ///
  ///   SqliteException(1): while executing, SQL logic error, SQL logic error (code 1)
  ///   Causing statement: ALTER TABLE "preferences_table" ADD COLUMN "cache_music" ...
  ///
  /// A migration that only works on a recent SQLite is a migration that can fail
  /// on a user's device, where the bundled SQLite version is whatever the OEM
  /// shipped. Asking first removes the dependency on the engine's error message
  /// and on its tolerance, and makes re-running a step harmless.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final rows = await customSelect("PRAGMA table_info(${table.actualTableName})").get();
    final present = rows.map((row) => row.read<String>('name')).toSet();
    // ignore: avoid_print
    print('DIAGADD ${table.actualTableName}.${column.name} exists=${present.contains(column.name)} all=$present');
    if (present.contains(column.name)) return;
    await m.addColumn(table, column);
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationSupportDirectory();
    final file = File(join(dbFolder.path, 'db.sqlite'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to sandboxing.
    final cacheBase = (await getTemporaryDirectory()).path;
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = cacheBase;

    return NativeDatabase.createInBackground(file);
  });
}
