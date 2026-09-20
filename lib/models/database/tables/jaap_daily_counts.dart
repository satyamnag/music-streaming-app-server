part of '../database.dart';

/// One row per counter per calendar day.
///
/// `day` is a local `YYYY-MM-DD` string, not a DateTime: streaks and the 7-day
/// strip are calendar-day questions, and a text day avoids timezone bugs where
/// a late-evening tap would land on the wrong date.
///
/// The unique (counterId, day) constraint makes every write an idempotent
/// upsert. Deleting a counter removes its rows via the cascade.
class JaapDailyCountsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get counterId => integer().references(
        JaapCountersTable,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get day => text().withLength(min: 10, max: 10)();
  IntColumn get count => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {counterId, day},
      ];
}
