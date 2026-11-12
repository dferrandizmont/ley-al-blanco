// Civil days: the calendar day a person lives in, wherever the phone is.
//
// A "day" is not an instant: it is the calendar day of the phone's zone, so
// it ends at local midnight. To keep the rules testable (Madrid, Mexico,
// Tokyo...) every function takes the offset in minutes instead of reading the
// zone of the process: the tests can then simulate a trip without changing
// the time zone of the machine.

/// The civil day of the instant [utc] under the UTC offset [offsetMinutes]
/// (+60 for Madrid in winter, 0 for Canarias in winter, -360 for Mexico).
///
/// The result is a UTC midnight, so two civil days can be subtracted and the
/// number of days between them is exact (a day is never 23 or 25 hours long).
DateTime civilDay(DateTime utc, int offsetMinutes) {
  final shifted = utc.toUtc().add(Duration(minutes: offsetMinutes));
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}

/// [day] moved [days] calendar days forward (calendar arithmetic: a month
/// rolls over, a day is never 23 or 25 hours long).
DateTime addCivilDays(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);

/// The instant of the start of the civil day [day] under [offsetMinutes]
/// (local midnight of that day).
DateTime startOfCivilDay(DateTime day, int offsetMinutes) => DateTime.utc(
  day.year,
  day.month,
  day.day,
).subtract(Duration(minutes: offsetMinutes));

/// ISO 8601 date (`2026-10-15`) of the civil day [day].
String isoDayOf(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-'
      '${two(day.day)}';
}

/// The offset of the device's zone (in minutes) at the instant [now].
int deviceOffsetMinutes(DateTime now) => now.toLocal().timeZoneOffset.inMinutes;

final RegExp _isoDayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// The calendar day of an ISO 8601 date string (a UTC midnight, so the
/// differences are whole days even across a daylight-saving change), or null
/// when [raw] is not a valid date.
DateTime? parseIsoDay(String? raw) {
  final match = raw == null ? null : _isoDayPattern.firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  // `DateTime.utc(2026, 2, 31)` rolls over to March: reject it.
  if (date.month != month || date.day != day) return null;
  return date;
}

/// Whole days from the day [from] to the day [to] (negative when [to] is
/// earlier).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
