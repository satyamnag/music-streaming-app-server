// TEMPORARY CI DIAGNOSTIC.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  test('sequential ALTERs on the real v1 table', () async {
    final db = v1.DatabaseAtV1(NativeDatabase.memory());
    Future<void> tryAlter(String label, String sql) async {
      try {
        await db.customStatement(sql);
        print('DIAG $label = OK');
      } catch (e) {
        print('DIAG $label = FAILED: $e');
      }
    }

    await tryAlter('1 invidious_instance',
        'ALTER TABLE "preferences_table" ADD COLUMN "invidious_instance" TEXT NOT NULL DEFAULT \'\';');
    await tryAlter('2 cache_music',
        'ALTER TABLE "preferences_table" ADD COLUMN "cache_music" INTEGER NOT NULL DEFAULT 1 CHECK ("cache_music" IN (0, 1));');
    await tryAlter('3 youtube_client_engine',
        'ALTER TABLE "preferences_table" ADD COLUMN "youtube_client_engine" TEXT NOT NULL DEFAULT \'youtubeExplode\';');
    final cols = await db
        .customSelect('PRAGMA table_info(preferences_table)')
        .get();
    print('DIAG cols = ${cols.map((r) => r.read<String>('name')).toList()}');
    await db.close();
  });
}