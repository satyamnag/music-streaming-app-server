// TEMPORARY CI DIAGNOSTIC - reproduces the real v1 table then the real step.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('diagnose the real statement on the real v1 table shape', () {
    final db = sqlite3.openInMemory();
    print('DIAG libVersion = ${sqlite3.version.libVersion}');
    db.execute('''
      CREATE TABLE "preferences_table" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "audio_quality" TEXT NOT NULL DEFAULT 'high',
        "album_color_sync" INTEGER NOT NULL DEFAULT 1 CHECK ("album_color_sync" IN (0, 1)),
        "close_behavior" TEXT NOT NULL DEFAULT 'close',
        "accent_color_scheme" TEXT NOT NULL DEFAULT 'maroon:0xff520101',
        "layout_mode" TEXT NOT NULL DEFAULT 'adaptive',
        "market" TEXT NOT NULL DEFAULT 'US',
        "locale" TEXT NOT NULL,
        "theme_mode" TEXT NOT NULL DEFAULT 'system',
        "audio_source" TEXT NOT NULL DEFAULT 'youtube',
        "discord_presence" INTEGER NOT NULL DEFAULT 1 CHECK ("discord_presence" IN (0, 1)),
        "endless_playback" INTEGER NOT NULL DEFAULT 0 CHECK ("endless_playback" IN (0, 1)),
        "enable_connect" INTEGER NOT NULL DEFAULT 0 CHECK ("enable_connect" IN (0, 1))
      )
    ''');
    final cols = db.select('PRAGMA table_info(preferences_table)')
        .map((r) => r['name']).toList();
    print('DIAG has cache_music before = ${cols.contains('cache_music')}');
    try {
      db.execute(
        'ALTER TABLE "preferences_table" ADD COLUMN "cache_music" INTEGER NOT NULL DEFAULT 1 CHECK ("cache_music" IN (0, 1));',
      );
      print('DIAG ADD on real v1 shape = OK');
    } catch (e) {
      print('DIAG ADD on real v1 shape = FAILED: $e');
    }
    db.dispose();
  });
}