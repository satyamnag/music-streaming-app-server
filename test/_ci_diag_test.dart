// TEMPORARY CI DIAGNOSTIC - removed once the runner difference is known.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('CI sqlite diagnostic', () {
    final db = sqlite3.openInMemory();
    print('DIAG libVersion = ${sqlite3.version.libVersion}');
    print('DIAG sourceId   = ${sqlite3.version.sourceId}');
    db.execute('CREATE TABLE preferences_table (id INTEGER PRIMARY KEY)');
    try {
      db.execute(
        'ALTER TABLE "preferences_table" ADD COLUMN "cache_music" INTEGER NOT NULL DEFAULT 1 CHECK ("cache_music" IN (0, 1));',
      );
      print('DIAG ADD COLUMN = OK');
    } catch (e) {
      print('DIAG ADD COLUMN = FAILED: $e');
    }
    db.dispose();
  });
}
