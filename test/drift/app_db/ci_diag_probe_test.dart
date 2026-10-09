// TEMPORARY CI DIAGNOSTIC - remove once the CI-only migration failures are
// understood. Runs on the CI runner (SQLite 3.37.2) and prints the state that
// makes `ALTER TABLE ... ADD COLUMN cache_music` fail there but not locally.
//
// ignore_for_file: avoid_print
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('CI DIAG: state at each stage of the v1 hop', () async {
    final connection = await verifier.startAt(1);

    // Inspect the raw v1 database BEFORE AppDatabase opens it.
    final executor = connection.executor;
    await executor.ensureOpen(_Probe(1));
    final rawTables = await executor.runSelect(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      const [],
    );
    final rawPrefs = await executor.runSelect(
      "PRAGMA table_info('preferences_table')",
      const [],
    );
    final rawVersion = await executor.runSelect('PRAGMA user_version', const []);
    final rawSqlite = await executor.runSelect(
      'SELECT sqlite_version() AS v',
      const [],
    );
    print('DIAG raw sqlite_version = ${rawSqlite.first['v']}');
    print('DIAG raw user_version = ${rawVersion.first.values.first}');
    print('DIAG raw tables = ${rawTables.map((r) => r['name']).toList()}');
    print('DIAG raw prefs count = ${rawPrefs.length}');
    print('DIAG raw prefs has cache_music = '
        '${rawPrefs.any((r) => r['name'] == 'cache_music')}');
    // Deliberately NOT closing: `startAt` shares one in-memory handle, so
    // closing the wrapper here would make the handover below fail.

    final db = AppDatabase.forTesting(connection);
    final v = await db.customSelect('SELECT sqlite_version() AS v').getSingle();
    print('DIAG after-open sqlite_version = ${v.read<String>('v')}');
    final uv = await db.customSelect('PRAGMA user_version').getSingle();
    print('DIAG after-open user_version = ${uv.data.values.first}');
    final cols = await db
        .customSelect("PRAGMA table_info('preferences_table')")
        .get();
    print('DIAG after-open prefs has cache_music = '
        '${cols.any((r) => r.read<String>('name') == 'cache_music')}');
    print('DIAG after-open prefs cols = '
        '${cols.map((r) => r.read<String>('name')).toList()}');
    await db.close();
  });
}

class _Probe extends QueryExecutorUser {
  @override
  final int schemaVersion;
  _Probe(this.schemaVersion);
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
