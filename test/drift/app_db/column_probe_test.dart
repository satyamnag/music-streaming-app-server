// Guards the fix: `pragma_table_info` must answer BOTH ways.
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

Future<bool> hasColumn(
  QueryExecutor db,
  String table,
  String column,
) async {
  final rows = await db.runSelect(
    'SELECT 1 AS present FROM pragma_table_info(?) WHERE name = ? LIMIT 1',
    [table, column],
  );
  return rows.isNotEmpty;
}

void main() {
  test('the column probe answers both ways', () async {
    final db = NativeDatabase.memory();
    await db.ensureOpen(_U());
    await db.runCustom(
      'CREATE TABLE t ("id" INTEGER NOT NULL, "cache_music" INTEGER NOT NULL)',
    );

    expect(await hasColumn(db, 't', 'cache_music'), isTrue,
        reason: 'an existing column must be reported present');
    expect(await hasColumn(db, 't', 'not_there'), isFalse,
        reason: 'a missing column must be reported absent');
    expect(await hasColumn(db, 'no_such_table', 'cache_music'), isFalse,
        reason: 'a missing table must report its columns absent');

    await db.close();
  });
}
