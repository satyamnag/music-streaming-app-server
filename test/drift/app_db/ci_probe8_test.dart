// TEMPORARY CI DIAGNOSTIC - does AUTOINCREMENT / the exact v1 table shape make
// ADD COLUMN ... CHECK fail on the runner's SQLite?
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
  test('CI DIAG: exact v1 preferences_table shape', () async {
    final db = NativeDatabase.memory();
    await db.ensureOpen(_U());

    final v = await db.runSelect('SELECT sqlite_version() AS v', const []);
    print('DIAG sqlite = ${v.single['v']}');

    // Verbatim reproduction of what the DDL diagnostic captured from the runner.
    await db.runCustom(
      'CREATE TABLE "preferences_table" ("id" INTEGER NOT NULL PRIMARY KEY '
      'AUTOINCREMENT, "audio_quality" TEXT NOT NULL DEFAULT \'high\', '
      '"album_color_sync" INTEGER NOT NULL DEFAULT 1 CHECK ("album_color_sync" IN (0, 1)), '
      '"amoled_dark_theme" INTEGER NOT NULL DEFAULT 0 CHECK ("amoled_dark_theme" IN (0, 1)), '
      '"check_update" INTEGER NOT NULL DEFAULT 1 CHECK ("check_update" IN (0, 1)), '
      '"normalize_audio" INTEGER NOT NULL DEFAULT 0 CHECK ("normalize_audio" IN (0, 1)), '
      '"show_system_tray_icon" INTEGER NOT NULL DEFAULT 0 CHECK ("show_system_tray_icon" IN (0, 1)), '
      '"system_title_bar" INTEGER NOT NULL DEFAULT 0 CHECK ("system_title_bar" IN (0, 1)), '
      '"skip_non_music" INTEGER NOT NULL DEFAULT 0 CHECK ("skip_non_music" IN (0, 1)), '
      '"close_behavior" TEXT NOT NULL DEFAULT \'close\', '
      '"accent_color_scheme" TEXT NOT NULL DEFAULT \'Blue:0xFF2196F3\', '
      '"layout_mode" TEXT NOT NULL DEFAULT \'adaptive\', '
      '"locale" TEXT NOT NULL DEFAULT \'{"languageCode":"system","countryCode":"system"}\', '
      '"market" TEXT NOT NULL DEFAULT \'US\', '
      '"search_mode" TEXT NOT NULL DEFAULT \'youtube\', '
      '"download_location" TEXT NOT NULL DEFAULT \'\', '
      '"local_library_location" TEXT NOT NULL DEFAULT \'\', '
      '"piped_instance" TEXT NOT NULL DEFAULT \'https://pipedapi.kavin.rocks\', '
      '"theme_mode" TEXT NOT NULL DEFAULT \'system\', '
      '"audio_source" TEXT NOT NULL DEFAULT \'youtube\', '
      '"stream_music_codec" TEXT NOT NULL DEFAULT \'weba\', '
      '"download_music_codec" TEXT NOT NULL DEFAULT \'m4a\', '
      '"discord_presence" INTEGER NOT NULL DEFAULT 1 CHECK ("discord_presence" IN (0, 1)), '
      '"endless_playback" INTEGER NOT NULL DEFAULT 1 CHECK ("endless_playback" IN (0, 1)), '
      '"enable_connect" INTEGER NOT NULL DEFAULT 0 CHECK ("enable_connect" IN (0, 1)))',
    );

    try {
      await db.runCustom(
        'ALTER TABLE "preferences_table" ADD COLUMN "cache_music" INTEGER NOT NULL '
        'DEFAULT 1 CHECK ("cache_music" IN (0, 1))',
      );
      print('DIAG exact v1 shape = OK');
    } catch (e) {
      print('DIAG exact v1 shape = FAIL :: $e');
    }

    // And with one row present.
    await db.runCustom('INSERT INTO preferences_table (audio_quality) '
        'VALUES (\'high\')');
    try {
      await db.runCustom(
        'ALTER TABLE "preferences_table" ADD COLUMN "cache_music2" INTEGER NOT NULL '
        'DEFAULT 1 CHECK ("cache_music2" IN (0, 1))',
      );
      print('DIAG exact v1 shape + row = OK');
    } catch (e) {
      print('DIAG exact v1 shape + row = FAIL :: $e');
    }

    await db.close();
  });
}
