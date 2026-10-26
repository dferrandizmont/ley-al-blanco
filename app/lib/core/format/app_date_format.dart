import 'package:intl/intl.dart';

/// Spanish date / time formatting: 24 h clock, Monday-first weeks and the
/// short local form ("jue 23 oct"). The app is Spanish-only for now, so the
/// locale is fixed to `es`; call `initializeDateFormatting('es')` before use
/// outside a localized app (tests).
class AppDateFormat {
  const AppDateFormat();

  static const String _locale = 'es';

  /// Short weekday + day + month: "jue 23 oct".
  String shortDate(DateTime d) {
    final weekday = _stripDot(DateFormat.E(_locale).format(d));
    final month = _stripDot(DateFormat.MMM(_locale).format(d));
    return '$weekday ${d.day} $month';
  }

  /// Day, short month and year: "20 oct 2026".
  String dayMonthYear(DateTime d) =>
      '${d.day} ${_stripDot(DateFormat.MMM(_locale).format(d))} ${d.year}';

  /// Short month name without the trailing dot: "nov".
  String shortMonth(DateTime d) => _stripDot(DateFormat.MMM(_locale).format(d));

  /// "octubre 2026".
  String monthYear(DateTime d) => DateFormat('LLLL y', _locale).format(d);

  /// "jueves, 23 de octubre".
  String longDate(DateTime d) => DateFormat.MMMMEEEEd(_locale).format(d);

  /// "jueves".
  String weekdayLong(DateTime d) => DateFormat.EEEE(_locale).format(d);

  /// "jue".
  String weekdayShort(DateTime d) => _stripDot(DateFormat.E(_locale).format(d));

  /// 24 h time "18:30".
  String time(DateTime d) => DateFormat('HH:mm', _locale).format(d);

  /// "jue 23 oct – lun 26 oct".
  String shortDateRange(DateTime start, DateTime end) =>
      '${shortDate(start)} – ${shortDate(end)}';

  static String _stripDot(String s) =>
      s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}
