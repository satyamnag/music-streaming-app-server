// TEMPORARY CI DIAGNOSTIC.
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangeet/models/database/database.dart';
import 'generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('trace the real failing hop', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase.forTesting(schema.newConnection());

    // What does the database look like BEFORE the migration opens it?
    final before = await db
        .customSelect('PRAGMA table_info(preferences_table)')
        .get();
    print('DIAG before cols = ${before.map((r) => r.read<String>('name')).toList()}');

    try {
      await verifier.migrateAndValidate(db, 15);
      print('DIAG migrateAndValidate = OK');
    } catch (e) {
      print('DIAG migrateAndValidate = FAILED: $e');
    }
    await db.close();
  });
}