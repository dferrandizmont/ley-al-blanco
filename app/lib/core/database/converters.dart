import 'dart:convert';

import 'package:drift/drift.dart';

/// `List<String>` stored as a JSON array in a TEXT column.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      List.unmodifiable((jsonDecode(fromDb) as List).cast<String>());

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// `List<int?>` stored as a JSON array in a TEXT column (a mock's answers:
/// null = left blank).
class NullableIntListConverter extends TypeConverter<List<int?>, String> {
  const NullableIntListConverter();

  @override
  List<int?> fromSql(String fromDb) =>
      List.unmodifiable((jsonDecode(fromDb) as List).cast<int?>());

  @override
  String toSql(List<int?> value) => jsonEncode(value);
}

/// DateTime policy for every date column (see `app_database.dart`): always
/// written as UTC, always read back as local time.
///
/// With `store_date_time_values_as_text` Drift writes a local DateTime as
/// `2026-10-25 02:30:00.000 +01:00` (mixed offsets, which do not sort
/// lexicographically across a DST change) and reads a UTC one back as UTC.
/// Normalising here keeps every stored value `...Z`, so ORDER BY and range
/// comparisons in SQL are chronological, and callers always get local time.
class LocalUtcDateTimeConverter extends TypeConverter<DateTime, DateTime> {
  const LocalUtcDateTimeConverter();

  @override
  DateTime fromSql(DateTime fromDb) => fromDb.toLocal();

  @override
  DateTime toSql(DateTime value) => value.toUtc();
}
