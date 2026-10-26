import 'app_date_format.dart';

/// Short, human label of a bank edition id: `GC-2020-11` -> "GC nov-2020".
/// An id that does not look like `<prefix>-<yyyy>-<mm>` is returned as is.
///
/// Month names come from `intl` (Spanish); call `initializeDateFormatting`
/// first outside a localized app.
String editionLabel(String edition) {
  final match = RegExp(r'^(.+)-(\d{4})-(\d{2})$').firstMatch(edition);
  if (match == null) return edition;
  final year = int.parse(match.group(2)!);
  final month = int.parse(match.group(3)!);
  if (month < 1 || month > 12) return edition;
  final name = const AppDateFormat().shortMonth(DateTime(year, month));
  return '${match.group(1)} $name-$year';
}
