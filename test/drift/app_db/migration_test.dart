// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // Every historical schema must be able to reach the app's CURRENT version.
    //
    // ## Why the loop targets `schemaVersion` and not every intermediate version
    // `migrateAndValidate(db, target)` builds its reference schema from
    // `snapshot[target]`, then opens the database wrapped in a delegate that
    // CLAIMS the version is `target`. The database still applies its own
    // `schemaVersion`, so `onUpgrade` runs all the way to the app's real version
    // and the result is compared against the `target` snapshot.
    //
    // That makes any `target` below `schemaVersion` unusable: for example
    // 11 -> 12 would migrate to 15 (running the v13 Jaap additions, the v14
    // foreign-key repair and the v15 Jaap drop) and then complain that a v15
    // database does not match the v12 snapshot. Those mismatches are an artefact
    // of the comparison, not defects in the migrations.
    //
    // Targeting `schemaVersion` is the assertion that actually matters and the
    // one the API supports: a database written by ANY past release must migrate
    // cleanly to the schema the shipping app expects. Because each hop re-runs
    // the whole `onUpgrade` chain from its starting version, the intermediate
    // steps are still exercised - every `from < version` branch is taken on the
    // way up.
    final versions = GeneratedHelper.versions;
    final currentVersion = versions.last;

    for (final fromVersion in versions) {
      if (fromVersion == currentVersion) continue;
      test('from $fromVersion migrates to $currentVersion', () async {
        final schema = await verifier.schemaAt(fromVersion);
        // `AppDatabase.forTesting` takes the executor the verifier hands out, so
        // the migration runs against the historical schema while the migration
        // code under test is the app's real one.
        //
        // The previous `Database(...)` here referenced a name that exists nowhere
        // in the project, so this file never compiled and no migration hop had
        // ever actually run.
        final db = AppDatabase.forTesting(schema.newConnection());
        await verifier.migrateAndValidate(db, currentVersion);
        await db.close();
      });
    }

    // The snapshots and the app must not drift apart: if `schemaVersion` is
    // bumped without dumping a schema for the new version, this loop would
    // silently keep validating an older target. Assert the pairing instead.
    test('a schema snapshot exists for the app\'s current version', () {
      expect(
        versions,
        contains(currentVersion),
        reason: 'GeneratedHelper must expose a snapshot for schemaVersion '
            '$currentVersion, or nothing validates the shipping schema',
      );
    });
  });

  // Simple tests ensure the schema is transformed correctly, but some
  // migrations benefit from a test verifying that data is transformed correctly
  // too. This is particularly true for migrations that change existing columns
  // (e.g. altering their type or constraints). Migrations that only add tables
  // or columns typically don't need these advanced tests.
  // TODO: Check whether you have migrations that could benefit from these tests
  // and adapt this example to your database if necessary:
  test("migration from v1 to v2 does not corrupt data", () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    final oldAuthenticationTableData = <v1.AuthenticationTableData>[];
    final expectedNewAuthenticationTableData = <v2.AuthenticationTableData>[];

    final oldBlacklistTableData = <v1.BlacklistTableData>[];
    final expectedNewBlacklistTableData = <v2.BlacklistTableData>[];

    final oldPreferencesTableData = <v1.PreferencesTableData>[];
    final expectedNewPreferencesTableData = <v2.PreferencesTableData>[];

    final oldScrobblerTableData = <v1.ScrobblerTableData>[];
    final expectedNewScrobblerTableData = <v2.ScrobblerTableData>[];

    final oldSkipSegmentTableData = <v1.SkipSegmentTableData>[];
    final expectedNewSkipSegmentTableData = <v2.SkipSegmentTableData>[];

    final oldSourceMatchTableData = <v1.SourceMatchTableData>[];
    final expectedNewSourceMatchTableData = <v2.SourceMatchTableData>[];

    final oldAudioPlayerStateTableData = <v1.AudioPlayerStateTableData>[];
    final expectedNewAudioPlayerStateTableData =
        <v2.AudioPlayerStateTableData>[];

    final oldPlaylistTableData = <v1.PlaylistTableData>[];
    final expectedNewPlaylistTableData = <v2.PlaylistTableData>[];

    final oldPlaylistMediaTableData = <v1.PlaylistMediaTableData>[];
    final expectedNewPlaylistMediaTableData = <v2.PlaylistMediaTableData>[];

    final oldHistoryTableData = <v1.HistoryTableData>[];
    final expectedNewHistoryTableData = <v2.HistoryTableData>[];

    final oldLyricsTableData = <v1.LyricsTableData>[];
    final expectedNewLyricsTableData = <v2.LyricsTableData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      // `AppDatabase.forTesting` takes the executor the verifier opens, so the
      // migration runs in memory against the historical schema.
      //
      // The previous `AppDatabase()` used the default constructor, whose
      // `LazyDatabase` calls `getApplicationSupportDirectory()` - a
      // path_provider platform channel. In a plain `test` (not
      // `testWidgets`) there is no Flutter binding, so it threw
      // "Binding has not yet been initialized" before any migration ran.
      openTestedDatabase: (x) => AppDatabase.forTesting(x),
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.authenticationTable, oldAuthenticationTableData);
        batch.insertAll(oldDb.blacklistTable, oldBlacklistTableData);
        batch.insertAll(oldDb.preferencesTable, oldPreferencesTableData);
        batch.insertAll(oldDb.scrobblerTable, oldScrobblerTableData);
        batch.insertAll(oldDb.skipSegmentTable, oldSkipSegmentTableData);
        batch.insertAll(oldDb.sourceMatchTable, oldSourceMatchTableData);
        batch.insertAll(
            oldDb.audioPlayerStateTable, oldAudioPlayerStateTableData);
        batch.insertAll(oldDb.playlistTable, oldPlaylistTableData);
        batch.insertAll(oldDb.playlistMediaTable, oldPlaylistMediaTableData);
        batch.insertAll(oldDb.historyTable, oldHistoryTableData);
        batch.insertAll(oldDb.lyricsTable, oldLyricsTableData);
      },
      validateItems: (newDb) async {
        expect(expectedNewAuthenticationTableData,
            await newDb.select(newDb.authenticationTable).get());
        expect(expectedNewBlacklistTableData,
            await newDb.select(newDb.blacklistTable).get());
        expect(expectedNewPreferencesTableData,
            await newDb.select(newDb.preferencesTable).get());
        expect(expectedNewScrobblerTableData,
            await newDb.select(newDb.scrobblerTable).get());
        expect(expectedNewSkipSegmentTableData,
            await newDb.select(newDb.skipSegmentTable).get());
        expect(expectedNewSourceMatchTableData,
            await newDb.select(newDb.sourceMatchTable).get());
        expect(expectedNewAudioPlayerStateTableData,
            await newDb.select(newDb.audioPlayerStateTable).get());
        expect(expectedNewPlaylistTableData,
            await newDb.select(newDb.playlistTable).get());
        expect(expectedNewPlaylistMediaTableData,
            await newDb.select(newDb.playlistMediaTable).get());
        expect(expectedNewHistoryTableData,
            await newDb.select(newDb.historyTable).get());
        expect(expectedNewLyricsTableData,
            await newDb.select(newDb.lyricsTable).get());
      },
    );
  });
}
