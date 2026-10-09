// Guards the CI fix for `ALTER TABLE ... ADD COLUMN` with a drift-generated
// CHECK constraint.
//
// The migration chain adds 28 boolean columns, and drift renders each as
// `INTEGER NOT NULL DEFAULT x CHECK ("c" IN (0, 1))`. Older SQLite rejects a
// column definition carrying a CHECK inside ADD COLUMN with a bare
// `SqliteException(1): SQL logic error`, which failed every hop from v1..v8 on
// the CI runner while passing on a newer local engine.
//
// These tests pin the two halves of the fix:
//  1. the statement really does contain a CHECK when built the normal way (so
//     the regression this guards against is real and would reappear), and
//  2. the CHECK-free replacement produces a column with the same type, null
//     tolerance and default, so existing rows are backfilled identically.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

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

/// Rebuilds [column] the way `_addColumnWithoutCheck` does: same type, same
/// nullability, same default, but no CHECK.
GeneratedColumn<Object> _withoutCheck(
  GeneratedColumn<Object> column,
  GenerationContext context,
) {
  final constraints = StringBuffer();
  if (!column.$nullable) constraints.write('NOT NULL');

  final defaultValue = column.defaultValue;
  if (defaultValue != null) {
    if (constraints.isNotEmpty) constraints.write(' ');
    final needsBrackets = !defaultValue.isLiteral;
    constraints.write('DEFAULT ');
    if (needsBrackets) constraints.write('(');
    defaultValue.writeInto(context);
    if (needsBrackets) constraints.write(')');
    constraints.write(context.buffer.toString());
    context.buffer.clear();
  }

  return GeneratedColumn<Object>(
    column.name,
    column.tableName,
    column.$nullable,
    type: column.type,
    $customConstraints: constraints.toString(),
    defaultValue: defaultValue,
    requiredDuringInsert: column.requiredDuringInsert,
  );
}

/// Renders the ADD COLUMN statement drift would issue, without executing it.
///
/// `Migrator.addColumn` builds exactly this: the ALTER prefix, the column's own
/// definition, and a terminating semicolon. Only the column definition differs
/// between the normal and the CHECK-free path.
String _renderAddColumn(GeneratedColumn<Object> column, GenerationContext ctx) {
  // `writeColumnDefinition` writes into ctx.buffer, so seed it with the prefix
  // and read the completed statement back out.
  ctx.buffer
    ..clear()
    ..write('ALTER TABLE "preferences_table" ADD COLUMN ');
  column.writeColumnDefinition(ctx);
  return ctx.buffer.toString();
}

/// A drift database that exposes a [GenerationContext] and records statements.
class _Harness extends GeneratedDatabase {
  _Harness(QueryExecutor e) : super(e);

  final List<String> executed = [];

  GenerationContext get context => GenerationContext.fromDb(this);

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

  test('the CHECK-free statement drops CHECK but keeps type and default',
      () async {
    final sql = _renderAddColumn(_withoutCheck(_cacheMusicColumn(), harness.context), harness.context);
    print('FIXED   : $sql');

    expect(sql.contains('CHECK'), isFalse,
        reason: 'the whole point of the fix is that no CHECK is emitted');
    expect(sql.contains('INTEGER'), isTrue, reason: 'type must survive');
    expect(sql.contains('NOT NULL'), isTrue, reason: 'nullability must survive');
    expect(sql.contains('DEFAULT 1'), isTrue,
        reason: 'the default must survive as the SQL literal drift emits (1, '
            'not the Dart object Constant(true)), or ADD COLUMN fails on a '
            'NOT NULL column with existing rows');
  });

  test('the CHECK-free statement actually runs and backfills existing rows',
      () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);

    db.execute('''
      CREATE TABLE "preferences_table" (
        "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        "is_first_run" INTEGER NOT NULL DEFAULT 1
      );
    ''');
    db.execute('INSERT INTO preferences_table (is_first_run) VALUES (1);');

    final fixed =
        _renderAddColumn(_withoutCheck(_cacheMusicColumn(), harness.context), harness.context);
    db.execute(fixed);

    // The column exists with the intended type...
    final info = db.select('PRAGMA table_info(preferences_table)');
    final added = info.firstWhere((r) => r['name'] == 'cache_music');
    expect(added['notnull'], 1, reason: 'NOT NULL must be applied');
    expect(added['dflt_value'].toString(), '1',
        reason: 'the default must be applied');

    // ...and the pre-existing row was backfilled, not left null.
    final row = db.select('SELECT cache_music FROM preferences_table').first;
    expect(row['cache_music'], 1,
        reason: 'existing rows must receive the default value');
  });
}
