import 'package:drift/native.dart';
import 'package:sangeet/models/database/database.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('foreign key enforcement is enabled on open', () async {
    final row = await db.customSelect('PRAGMA foreign_keys;').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  test('deleting a counter cascades to its daily rows', () async {
    final counterId = await db.into(db.jaapCountersTable).insert(
          JaapCountersTableCompanion.insert(name: 'Gayatri'),
        );
    await db.into(db.jaapDailyCountsTable).insert(
          JaapDailyCountsTableCompanion.insert(
            counterId: counterId,
            day: '2025-09-20',
          ),
        );

    expect(await db.select(db.jaapDailyCountsTable).get(), hasLength(1));

    await (db.delete(db.jaapCountersTable)
          ..where((t) => t.id.equals(counterId)))
        .go();

    expect(await db.select(db.jaapDailyCountsTable).get(), isEmpty);
  });

  test('a daily row referencing a missing counter is rejected', () async {
    await expectLater(
      db.into(db.jaapDailyCountsTable).insert(
            JaapDailyCountsTableCompanion.insert(
              counterId: 999,
              day: '2025-09-20',
            ),
          ),
      throwsA(isA<SqliteException>()),
    );
  });
}
