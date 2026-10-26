// ISO 8601 helpers. Dates are date-only (`YYYY-MM-DD`) when all-day, else
// datetimes with a UTC offset. Offsets use the device time zone.

/// Parses an ISO date or datetime; datetimes are converted to local time.
DateTime? parseIso(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return value.contains('T') ? parsed.toLocal() : parsed;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// `YYYY-MM-DD`.
String toIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `YYYY-MM-DDTHH:mm:ss+02:00` using the offset of [local].
String toIsoDateTime(DateTime local) {
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final oh = _two(abs.inHours);
  final om = _two(abs.inMinutes.remainder(60));
  return '${toIsoDate(local)}T${_two(local.hour)}:${_two(local.minute)}:'
      '${_two(local.second)}$sign$oh:$om';
}

/// Strips the time part.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// [d]'s calendar date moved by [days] whole days, at midnight. Calendar
/// arithmetic, not `add(Duration(days: n))`: around a DST change a day lasts
/// 23 or 25 hours, so adding 24 h from midnight can land on 23:00 of the same
/// day (October) or 01:00 of the next (March).
DateTime shiftDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Monday-first start of week.
DateTime startOfWeek(DateTime d) =>
    shiftDays(d, -(d.weekday - DateTime.monday));
