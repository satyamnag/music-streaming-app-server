part of '../database.dart';

class ColorConverter extends TypeConverter<Color, int> {
  const ColorConverter();

  @override
  Color fromSql(int fromDb) {
    return Color(fromDb);
  }

  @override
  int toSql(Color value) {
    return value.toARGB32();
  }
}

class SangeetColorConverter extends TypeConverter<SangeetColor, String> {
  const SangeetColorConverter();

  @override
  SangeetColor fromSql(String fromDb) {
    return SangeetColor.fromString(fromDb);
  }

  @override
  String toSql(SangeetColor value) {
    return value.toString();
  }
}
