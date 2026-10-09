// TEMPORARY CI DIAGNOSTIC - remove once the CI-only migration failures are
// understood. Isolates the single ALTER that fails on the CI runner's SQLite.
//
// ignore_for_file: avoid_print
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

Future<void> attempt(NativeDatabase db, String label, String sql) async {
  try {
    await db.runCustom(sql);
    print('DIAG $label = OK');
  } catch (e) {
    print('DIAG $label = FAIL :: $e');
  }
}

void main() {
  test('CI DIAG: ADD COLUMN CHECK behaviour', () async {
    final db = NativeDatabase.memory();
    await db.ensureOpen(_U());

    final v = await db.runSelect('SELECT sqlite_version() AS v', const []);
    print('DIAG sqlite = ${v.single['v']}');

    // Mirror a v1 preferences_table in the two relevant shapes.
    await db.runCustom(
      'CREATE TABLE p ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"audio_quality" TEXT NOT NULL DEFAULT \'high\')',
    );

    await attempt(
      db,
      'empty-table CHECK',
      'ALTER TABLE p ADD COLUMN "cache_music" INTEGER NOT NULL DEFAULT 1 '
          'CHECK ("cache_music" IN (0, 1))',
    );

    await db.runCustom('INSERT INTO p (audio_quality) VALUES (\'high\')');

    await attempt(
      db,
      'one-row CHECK',
      'ALTER TABLE p ADD COLUMN "second_flag" INTEGER NOT NULL DEFAULT 0 '
          'CHECK ("second_flag" IN (0, 1))',
    );

    await attempt(
      db,
      'one-row NO-CHECK',
      'ALTER TABLE p ADD COLUMN "plain_flag" INTEGER NOT NULL DEFAULT 0',
    );

    // Does a rebuild-style rename+drop sequence work on this SQLite?
    await attempt(
      db,
      'rename column',
      'ALTER TABLE p RENAME COLUMN audio_quality TO audio_quality_old',
    );
    await attempt(
      db,
      'add after rename',
      'ALTER TABLE p ADD COLUMN audio_quality TEXT NOT NULL DEFAULT \'high\'',
    );
    await attempt(
      db,
      'drop column',
      'ALTER TABLE p DROP COLUMN audio_quality_old',
    );

    await db.close();
  });
}

class _U extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;
  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
