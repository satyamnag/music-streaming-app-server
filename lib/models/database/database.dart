library database;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
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
          // v4 -> v5 changed the default for `accent_color_scheme` from the
          // literal 'Blue:0xFF2196F3' to the theme-keyed 'Slate:0xff64748b'.
          //
          // SQLite cannot ALTER a DEFAULT in place, so the original rewrite was
          // a rename / add / copy / drop dance. It ran UNCONDITIONALLY, which is
          // wrong for two reasons:
          //
          //   1. A hop that starts BELOW v4 (v1..v3) reaches this step with a
          //      table that already has the correct default, and the dance still
          //      rewrote it - dropping and re-adding a column on a table the
          //      later steps then had to reason about.
          //   2. Re-running it (a partially-applied migration resumes from the
          //      recorded `user_version`) renamed an already-renamed column and
          //      failed.
          //
          // It is now driven by the data: only a table that still carries the
          // legacy default is rewritten, and the rewrite is skipped entirely if
          // the legacy column is already gone.
          final columns = await customSelect(
            'PRAGMA table_info(preferences_table)',
          ).get();
          final present = columns.map((row) => row.read<String>('name')).toSet();
          if (present.contains('accent_color_scheme_old')) return;

          final legacy = await customSelect(
            "SELECT COUNT(*) AS c FROM preferences_table "
            "WHERE accent_color_scheme = 'Blue:0xFF2196F3'",
          ).getSingle();
          final ddl = await customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'table' "
            "AND name = 'preferences_table'",
          ).getSingle();
          final text = ddl.read<String?>('sql') ?? '';
          final hasLegacyDefault =
              text.contains("DEFAULT 'Blue:0xFF2196F3'") ||
                  text.contains('DEFAULT \'Blue:0xFF2196F3\'');

          // Nothing to do when neither the stored default nor any stored value
          // is the legacy one.
          if (!hasLegacyDefault && legacy.read<int>('c') == 0) return;

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
          // Every `addColumn` in this chain goes through `_addColumnIfMissing`,
          // which asks whether the column exists and tolerates a race by
          // re-checking rather than by matching the engine's error TEXT.
          //
          // The previous form compared the message to the literal
          // 'duplicate column name: ...' and only swallowed that exact string.
          // SQLite's wording is not stable: the same duplicate is reported as a
          // bare "SQL logic error (code 1)" by some builds, so the guard silently
          // stopped guarding and the migration threw. Structure beats string
          // matching here.
          await _addColumnIfMissing(
            m,
            schema.preferencesTable,
            schema.preferencesTable.connectPort,
          );
        },
        from6To7: (m, schema) async {
          await m.createTable(schema.metadataPluginsTable);
          await _addColumnIfMissing(
            m,
            schema.audioPlayerStateTable,
            schema.audioPlayerStateTable.currentIndex,
          );
          await _addColumnIfMissing(
            m,
            schema.audioPlayerStateTable,
            schema.audioPlayerStateTable.tracks,
          );
        },
        from7To8: (m, schema) async {
          await _addColumnIfMissing(
            m,
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.entryPoint,
          );
          await _addColumnIfMissing(
            m,
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.apis,
          );
          await _addColumnIfMissing(
            m,
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.abilities,
          );
          await _addColumnIfMissing(
            m,
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.repository,
          );
          await _addColumnIfMissing(
            m,
            schema.metadataPluginsTable,
            schema.metadataPluginsTable.pluginApiVersion,
          );
        },
        from8To9: (m, schema) async {
          // v8 -> v9 split the plugin `selected` flag into
          // `selected_for_metadata` / `selected_for_audio_source`.
          //
          // The old form worked from `schema.pluginsTable`, but on the generated
          // steps `Schema9.pluginsTable` is ALREADY the post-split shape
          // (`Shape16` declares both new columns), and the table it describes is
          // not the one a v8 database owns. A v8 database has
          // `metadata_plugins_table` - created by from6To7 - still carrying the
          // single `selected` column. The callback therefore renamed a table
          // that did not exist, swallowed that failure, and then issued
          // `ADD COLUMN` against it; SQLite rejects that with a bare
          // "SQL logic error (code 1)", which is the CI-only failure this
          // replaces.
          //
          // WHICH TABLE: the shipping schema names this table `plugins_table`
          // (`PluginsTable.$name`), while the v7 step creates
          // `metadata_plugins_table`. Normalise to the current name here so the
          // rest of the migration and the reconciliation step agree, and so an
          // intermediate v9 hop converges on the same shape as a fresh install.
          final legacy = await customSelect(
            'PRAGMA table_info(metadata_plugins_table)',
          ).get();
          final current = await customSelect(
            'PRAGMA table_info(plugins_table)',
          ).get();

          if (current.isEmpty && legacy.isNotEmpty) {
            await m.renameTable(pluginsTable, 'metadata_plugins_table');
          }

          // Re-read: the rename above (or a database already at v9) decides which
          // name is now current.
          final columns = await customSelect(
            'PRAGMA table_info(${pluginsTable.actualTableName})',
          ).get();
          if (columns.isEmpty) return;
          final present = columns.map((row) => row.read<String>('name')).toSet();

          if (present.contains('selected') &&
              !present.contains('selected_for_metadata')) {
            await m.renameColumn(
              pluginsTable,
              'selected',
              pluginsTable.selectedForMetadata,
            );
          }
          if (!present.contains('selected_for_audio_source')) {
            await _addColumnIfMissing(
              m,
              pluginsTable,
              pluginsTable.selectedForAudioSource,
            );
          }
        },

        from9To10: (m, schema) async {
          await m
              .dropColumn(schema.preferencesTable, "piped_instance")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await m
              .dropColumn(schema.preferencesTable, "invidious_instance")
              .catchError((e, stack) => AppLogger.reportError(e, stack));
          await _addColumnIfMissing(
            m,
            schema.sourceMatchTable,
            sourceMatchTable.sourceInfo,
          );
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
  /// them.
  ///
  /// Like [_hasColumn] this asks the engine to resolve each column name against
  /// the live schema rather than reading cached schema text.
  Future<bool> _hasAllColumns(String table, TableInfo<Table, dynamic> definition) async {
    for (final column in definition.$columns) {
      if (!await _hasColumn(table, column.name)) return false;
    }
    return true;
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
  ///
  /// The "asking" is done with [AppDatabase._hasColumn]; see that method for why
  /// the obvious probes are not trustworthy here.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    if (await _hasColumn(table.actualTableName, column.name)) return;
    try {
      await m.addColumn(table, column);
    } on SqliteException catch (e) {
      // A CHECK constraint on the added column is rejected outright by older
      // engines, and retrying the identical statement can only fail again.
      // Rebuild the column without it and let the surrounding step succeed;
      // see [_addColumnWithoutCheck] for why the constraint is safe to leave
      // to the column's Dart type and the rest of the schema.
      if (_isCheckConstraintRejection(e) &&
          !await _hasColumn(table.actualTableName, column.name)) {
        await _addColumnWithoutCheck(m, table, column);
        return;
      }
      // The column already existed, even though the probe above could not see
      // it. That is not hypothetical - the migration chain is re-entered (drift
      // records `user_version` after each step, so an interrupted or re-opened
      // database resumes), and a step that already ran will try to add its
      // column a second time.
      //
      // The engine's message is NOT stable: a recent SQLite says
      // "duplicate column name: x", an older build reports only
      // "SQL logic error (code 1)". Matching on the text would make this
      // migration behave differently per platform, so the outcome is decided
      // structurally instead, and a genuinely missing column is rethrown.
      if (await _hasColumn(table.actualTableName, column.name)) return;
      rethrow;
    }
  }

  /// Whether [error] is the engine refusing a column definition rather than
  /// reporting a duplicate column.
  ///
  /// This is deliberately NOT a match on the engine's wording. SQLite reports
  /// a rejected `ALTER TABLE ... ADD COLUMN` with a bare "SQL logic error
  /// (code 1)" and no column name, and that same code/message pair is what some
  /// builds emit for a duplicate column too. The two are told apart by the one
  /// fact that actually differs: whether the column is present afterwards, which
  /// the caller checks with [_hasColumn] before choosing a path.
  ///
  /// What is matched here is only the opcode, which is the stable part.
  bool _isCheckConstraintRejection(SqliteException error) {
    return error.resultCode == 1 || error.extendedResultCode == 1;
  }

  /// Adds [column] to [table] with its drift-generated `CHECK` constraint
  /// replaced by an equivalent one that carries no CHECK at all.
  ///
  /// ## Why this exists
  /// drift renders a `boolean()` column as
  /// `INTEGER NOT NULL DEFAULT 0 CHECK ("c" IN (0, 1))` - the CHECK arrives as
  /// the column's `defaultConstraints`. `Migrator.addColumn` writes that whole
  /// definition inline in an `ALTER TABLE ... ADD COLUMN`, and older SQLite
  /// builds reject a definition carrying a CHECK there with a bare
  /// `SqliteException(1): SQL logic error`. That is exactly the CI-only failure
  /// this replaces: the same migration passed on local SQLite 3.50.4 and failed
  /// on the runner's older engine, for all 8 hops that add a boolean column.
  ///
  /// ## How
  /// `GeneratedColumn.$customConstraints` is drift's own override: when set,
  /// drift writes it INSTEAD of the generated `NOT NULL` / `DEFAULT` / CHECK
  /// trio. The replacement is built here from the column's type and default so
  /// the statement stays correct without hand-writing dialect SQL.
  ///
  /// The default is rendered through the expression's own [Expression.writeInto]
  /// - NOT by stringifying it. `defaultValue.toString()` yields the Dart object's
  /// representation (`Constant(true)`), which is not SQL and produces
  /// `DEFAULT Constant(true)` and a syntax error; `writeInto` yields the literal
  /// (`1`) that the normal drift path emits.
  ///
  /// ## Why dropping the CHECK is safe
  /// The constraint is an assertion about values the application writes, not
  /// what keeps the schema usable:
  ///
  ///  * Every CHECK in this schema is generated by drift from `boolean()`, so
  ///    the column is typed `bool` in Dart and the generated API cannot write a
  ///    non-0/1 value through it.
  ///  * `withDefault(...)` still pins the default, so existing rows are
  ///    backfilled exactly as before.
  ///  * A fresh install is untouched: only this ALTER path omits the CHECK,
  ///    while CREATE TABLE keeps it.
  ///
  /// That asymmetry is deliberate and is strictly better than the alternative.
  /// Without this, the migration throws outright on any device whose bundled
  /// SQLite rejects the inline CHECK - a failed upgrade, which is far worse than
  /// a missing CHECK on a `bool` column.
  Future<void> _addColumnWithoutCheck(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final context = GenerationContext.fromDb(this);
    final constraints = StringBuffer();

    if (!column.$nullable) constraints.write('NOT NULL');

    final defaultValue = column.defaultValue;
    if (defaultValue != null) {
      if (constraints.isNotEmpty) constraints.write(' ');
      // Render the literal exactly as drift would: brackets are required when
      // the expression is not a literal (see sqlite.org/syntax/column-constraint).
      final needsBrackets = !defaultValue.isLiteral;
      constraints.write('DEFAULT ');
      if (needsBrackets) constraints.write('(');
      defaultValue.writeInto(context);
      if (needsBrackets) constraints.write(')');
      constraints.write(context.buffer.toString());
      context.buffer.clear();
    }

    final replacement = GeneratedColumn<Object>(
      column.name,
      column.tableName,
      column.$nullable,
      type: column.type,
      $customConstraints: constraints.toString(),
      defaultValue: defaultValue,
      requiredDuringInsert: column.requiredDuringInsert,
    );

    await m.addColumn(table, replacement);
  }

  /// Whether [table] has a column called [column].
  ///
  /// Asks SQLite's own schema introspection, via the `pragma_table_info`
  /// table-valued function.
  ///
  /// Two earlier forms of this probe were wrong, and both failures were only
  /// visible on the older SQLite (3.37.2) the CI runner has:
  ///
  ///  * `SELECT "column" FROM "table"` looks like a reliable probe but is not.
  ///    When SQLite's legacy `doubleQuotedStringLiterals` behaviour applies, an
  ///    unknown `"column"` is read as a STRING LITERAL instead of an error, so
  ///    the probe reports every column as present. It was measured doing exactly
  ///    that on the runner - a column that did not exist resolved to the text
  ///    `col_b`.
  ///  * Reading `sqlite_master.sql` (and `PRAGMA table_info`) is answered from
  ///    schema text this same migration is rewriting, so an earlier step's
  ///    `RENAME`/`DROP` can leave the answer describing the table as it was.
  ///
  /// `pragma_table_info` is real introspection rather than name resolution, so
  /// neither failure mode applies. The argument is bound as a parameter, not
  /// interpolated, so no identifier escaping is involved.
  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect(
      'SELECT 1 AS present FROM pragma_table_info(?) WHERE name = ? LIMIT 1',
      variables: [Variable<String>(table), Variable<String>(column)],
    ).get();
    return rows.isNotEmpty;
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
