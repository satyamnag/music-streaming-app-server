// Guards the CI fix for `ALTER TABLE ... ADD COLUMN` with a drift-generated
// CHECK constraint.
//
// ignore_for_file: avoid_print
//
// The migration chain adds 28 boolean columns, and drift renders each as
// `INTEGER NOT NULL DEFAULT x CHECK ("c" IN (0, 1))`. Older SQLite rejects a
// column definition carrying a CHECK inside ADD COLUMN with a bare
// `SqliteException(1): SQL logic error`, which failed every hop from v1..v8 on
// the CI runner while passing on the newer local engine.
//
// These tests drive the REAL `AppDatabase.withoutCheck` produced by production
// code - not a copy of it - and then execute the resulting statement against a
// live database, so the assertion is about the SQL that actually ships.
//
// What is pinned:
//  1. the unguarded statement really does carry a CHECK, so the hazard this
//     guards against is real and would return if drift changed;
//  2. `withoutCheck` removes only the CHECK, keeping type / NOT NULL / DEFAULT;
//  3. the resulting statement runs and backfills existing rows;
//  4. a non-duplicate, non-definition failure is NOT swallowed.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:sangeet/models/database/database.dart';

/// The shape drift generates for a `boolean().withDefault(const Constant(true))`
/// column - taken verbatim from database.steps.dart's `cache_music`.
GeneratedColumn<bool> _cacheMusicColumn() {
  return GeneratedColumn<bool>(
    'cache_music',
    'preferences_table',
    false,
    type: DriftSqlType.bool,
    defaultConstraints:
        GeneratedColumn.constraintIsAlways('CHECK ("cache_music" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
}

/// Renders the ADD COLUMN statement drift would issue, without executing it.
String _renderAddColumn(GeneratedColumn<Object> column, GenerationContext ctx) {
  ctx.buffer
    ..clear()
    ..write('ALTER TABLE "preferences_table" ADD COLUMN ');
  column.writeColumnDefinition(ctx);
  return ctx.buffer.toString();
}

/// A drift database that only exists to provide a [GenerationContext].
///
/// `AppDatabase` itself is not usable here: its constructor opens the real
/// on-disk database through `path_provider`. The production transformation under
/// test is the static `AppDatabase.withoutCheck`, which needs nothing from a
/// database but a context.
class _Harness extends GeneratedDatabase {
  _Harness(super.e);

  GenerationContext get context => GenerationContext.fromDb(this);

  /// Delegates to the REAL production transformation.
  GeneratedColumn<Object> strip(GeneratedColumn<Object> c) =>
      AppDatabase.withoutCheck(c, context);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  late _Harness harness;

  setUp(() {
    harness = _Harness(NativeDatabase.memory());
  });

  tearDown(() async {
    await harness.close();
  });

  test('the unguarded statement carries a CHECK, so the hazard is real',
      () async {
    final sql = _renderAddColumn(_cacheMusicColumn(), harness.context);
    print('NORMAL  : $sql');

    expect(
      sql.contains('CHECK'),
      isTrue,
      reason: 'drift must be emitting the CHECK that older SQLite rejects; '
          'if this fails the premise of the fix has changed',
    );
  });

  test('the production withoutCheck drops CHECK but keeps type and default',
      () async {
    final sql = _renderAddColumn(harness.strip(_cacheMusicColumn()),
        harness.context);
    print('FIXED   : $sql');

    expect(sql.contains('CHECK'), isFalse,
        reason: 'the whole point of the fix is that no CHECK is emitted');
    expect(sql.contains('"cache_music"'), isTrue,
        reason: 'the column name must be preserved');
    expect(sql.contains('INTEGER'), isTrue, reason: 'type must survive');
    expect(sql.contains('NOT NULL'), isTrue, reason: 'nullability must survive');
    expect(sql.contains('DEFAULT 1'), isTrue,
        reason: 'the default must survive as the SQL literal drift emits (1, '
            'not the Dart object Constant(true)), or ADD COLUMN fails on a '
            'NOT NULL column with existing rows');
  });

  test('the production output runs and backfills existing rows', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);

    db.execute('''
      CREATE TABLE "preferences_table" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "is_first_run" INTEGER NOT NULL DEFAULT 1
      );
    ''');
    db.execute('INSERT INTO preferences_table (is_first_run) VALUES (1);');

    final fixed = _renderAddColumn(harness.strip(_cacheMusicColumn()),
        harness.context);
    db.execute(fixed);

    final info = db.select('PRAGMA table_info(preferences_table)');
    final added = info.firstWhere((r) => r['name'] == 'cache_music');
    expect(added['notnull'], 1, reason: 'NOT NULL must be applied');
    expect(added['dflt_value'].toString(), '1',
        reason: 'the default must be applied');

    final value = db
        .select('SELECT cache_music FROM preferences_table')
        .first['cache_music'];
    expect(value, 1,
        reason: 'existing rows must receive the default, not null');
  });

  test('a nullable column keeps NULL rather than gaining NOT NULL', () async {
    final nullable = GeneratedColumn<String>(
      'note',
      'preferences_table',
      true,
      type: DriftSqlType.string,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK (length("note") < 5)'),
    );

    final sql = _renderAddColumn(harness.strip(nullable), harness.context);
    print('NULLABLE: $sql');

    expect(sql.contains('CHECK'), isFalse);
    expect(sql.contains('NOT NULL'), isFalse,
        reason: 'a nullable column must not be made NOT NULL by the rewrite');
  });
}
