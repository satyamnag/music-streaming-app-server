// TEMPORARY CI DIAGNOSTIC - deleted once the runner difference is known.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  test('dump the real v1 CREATE TABLE and the failing ALTER', () async {
    final db = v1.DatabaseAtV1(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    final sql = await db
        .customSelect("SELECT sql FROM sqlite_master WHERE name='preferences_table'")
        .getSingleOrNull();
    print('DIAG CREATE = ${sql?.read<String>('sql')}');
    try {
      await db.customStatement(
        'ALTER TABLE "preferences_table" ADD COLUMN "cache_music" INTEGER NOT NULL DEFAULT 1 CHECK ("cache_music" IN (0, 1));',
      );
      print('DIAG ALTER = OK');
    } catch (e) {
      print('DIAG ALTER = FAILED: $e');
    }
    await db.close();
  });
}