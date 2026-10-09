// TEMPORARY CI DIAGNOSTIC - is ADD COLUMN ... CHECK rejected inside a
// transaction on the runner's SQLite? That is the last untested difference
// between the isolated probe (which passed) and the real migration.
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
  test('CI DIAG: ADD COLUMN CHECK inside a transaction', () async {
    final db = NativeDatabase.memory();
    await db.ensureOpen(_U());

    final v = await db.runSelect('SELECT sqlite_version() AS v', const []);
    print('DIAG sqlite = ${v.single['v']}');

    await db.runCustom(
      'CREATE TABLE "p" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      '"a" TEXT NOT NULL DEFAULT \'x\', '
      '"b" INTEGER NOT NULL DEFAULT 1 CHECK ("b" IN (0, 1)))',
    );
    await db.runCustom('INSERT INTO p (a) VALUES (\'x\')');

    // OUTSIDE a transaction.
    try {
      await db.runCustom(
        'ALTER TABLE "p" ADD COLUMN "c1" INTEGER NOT NULL DEFAULT 1 '
        'CHECK ("c1" IN (0, 1))',
      );
      print('DIAG outside transaction = OK');
    } catch (e) {
      print('DIAG outside transaction = FAIL :: $e');
    }

    // INSIDE an explicit transaction.
    await db.runCustom('BEGIN');
    try {
      await db.runCustom(
        'ALTER TABLE "p" ADD COLUMN "c2" INTEGER NOT NULL DEFAULT 1 '
        'CHECK ("c2" IN (0, 1))',
      );
      print('DIAG inside transaction = OK');
    } catch (e) {
      print('DIAG inside transaction = FAIL :: $e');
    }
    await db.runCustom('COMMIT');

    // INSIDE a transaction with foreign_keys ON (what beforeOpen sets).
    await db.runCustom('PRAGMA foreign_keys = ON');
    await db.runCustom('BEGIN');
    try {
      await db.runCustom(
        'ALTER TABLE "p" ADD COLUMN "c3" INTEGER NOT NULL DEFAULT 1 '
        'CHECK ("c3" IN (0, 1))',
      );
      print('DIAG in txn + fk ON = OK');
    } catch (e) {
      print('DIAG in txn + fk ON = FAIL :: $e');
    }
    await db.runCustom('COMMIT');

    await db.close();
  });
}
