import 'package:hetu_script/values.dart';

/// Converts a Hetu script return value into a plain JSON-compatible Dart
/// value so it can be decoded by the models' `fromJson` factories.
///
/// Hetu's object literals are represented as [HTStruct] (not `Map`), so a
/// direct `as Map` cast throws `HTStruct is not a subtype of Map`. This helper
/// normalizes structs, lists of structs, and nested structures into plain
/// `Map` / `List` values.
dynamic hetuToJson(dynamic value) {
  if (value is HTStruct) {
    return value.toJson();
  }
  if (value is List) {
    return value.map(hetuToJson).toList();
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), hetuToJson(item)),
    );
  }
  return value;
}

/// Casts a Hetu return value to a `Map<String, dynamic>`.
Map<String, dynamic> hetuToMap(dynamic value) {
  return Map<String, dynamic>.from(hetuToJson(value) as Map);
}

/// Casts a Hetu return value to a `List<dynamic>`.
List<dynamic> hetuToList(dynamic value) {
  return hetuToJson(value) as List<dynamic>;
}
