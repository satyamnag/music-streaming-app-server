// TEMPORARY CI DIAGNOSTIC - does a failing/succeeding SELECT immediately before
// the ALTER change whether the ALTER succeeds on the runner's SQLite?
//
// ignore_for_file: avoid_print
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

class _U extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}

void main() {
  test('CI DIAG: SELECT then ALTER', () async {
    final db = NativeDatabase.memory();
    await db.ensureOpen(_U());

    final v = await db.runSelect('SELECT sqlite_version() AS v', const []);
    print('DIAG sqlite = ${v.single['v']}');

    await db.runCustom(
      'CREATE TABLE "preferences_table" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "audio_quality" TEXT NOT NULL DEFAULT \'high\', '
      '"album_color_sync" INTEGER NOT NULL DEFAULT 1 CHECK ("album_color_sync" IN (0, 1)), '
      '"market" TEXT NOT NULL DEFAULT \'US\')',
    );

    // Case A: no preceding SELECT.
    try {
      await db.runCustom(
        'ALTER TABLE "preferences_table" ADD COLUMN "col_a" INTEGER NOT NULL '
        'DEFAULT 1 CHECK ("col_a" IN (0, 1))',
      );
      print('DIAG A (no preceding SELECT) = OK');
    } catch (e) {
      print('DIAG A (no preceding SELECT) = FAIL :: $e');
    }

    // Case B: a FAILING select (the missing-column probe) runs first.
    try {
      await db.runSelect(
        'SELECT "col_b" FROM "preferences_table" WHERE false',
        const [],
      );
      print('DIAG B probe unexpectedly succeeded');
    } catch (_) {
      // expected: no such column
    }
    try {
      await db.runCustom(
        'ALTER TABLE "preferences_table" ADD COLUMN "col_b" INTEGER NOT NULL '
        'DEFAULT 1 CHECK ("col_b" IN (0, 1))',
      );
      print('DIAG B (after failing SELECT) = OK');
    } catch (e) {
      print('DIAG B (after failing SELECT) = FAIL :: $e');
    }

    await db.close();
  });
}
