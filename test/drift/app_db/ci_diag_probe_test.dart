// TEMPORARY CI DIAGNOSTIC - remove once the CI-only migration failures are
// understood. Deliberately does NOT probe the connection before handing it to
// `AppDatabase`, so the upgrade path runs exactly as it does in the real test.
//
// ignore_for_file: avoid_print
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  for (final fromVersion in [1, 2, 3, 8, 9]) {
    test('CI DIAG from $fromVersion', () async {
      final connection = await verifier.startAt(fromVersion);
      final db = AppDatabase.forTesting(connection);

      final v = await db.customSelect('SELECT sqlite_version() AS v').getSingle();
      final uvBefore = await db.customSelect('PRAGMA user_version').getSingle();
      print('DIAG[$fromVersion] sqlite=${v.read<String>('v')} '
          'user_version_before=${uvBefore.data.values.first}');

      try {
        await verifier.migrateAndValidate(db, 15);
        print('DIAG[$fromVersion] RESULT=success');
      } catch (e) {
        final msg = e.toString().split('\n').first;
        print('DIAG[$fromVersion] RESULT=failed :: $msg');
      }

      final uvAfter = await db.customSelect('PRAGMA user_version').getSingle();
      final cols = await db
          .customSelect("PRAGMA table_info('preferences_table')")
          .get();
      print('DIAG[$fromVersion] user_version_after='
          '${uvAfter.data.values.first} '
          'has_cache_music=${cols.any((r) => r.read<String>('name') == 'cache_music')}');
      await db.close();
    });
  }
}
