part of '../database.dart';

/// A named japa practice, e.g. "Gayatri" or "Nama".
///
/// The daily target (vow / sankalpa) lives here rather than on the daily row so
/// that changing the target does not rewrite history.
class JaapCountersTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  IntColumn get dailyTarget => integer().withDefault(const Constant(108))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
