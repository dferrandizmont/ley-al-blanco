import 'package:apto_armas/core/format/app_date_format.dart';
import 'package:apto_armas/core/format/iso.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('AppDateFormat (es)', () {
    const f = AppDateFormat();
    final d = DateTime(2026, 10, 15, 18, 30); // Thursday

    test('short, long and time forms', () {
      expect(f.shortDate(d), 'jue 15 oct');
      expect(f.weekdayLong(d), 'jueves');
      expect(f.weekdayShort(d), 'jue');
      expect(f.time(d), '18:30');
      expect(f.longDate(d), 'jueves, 15 de octubre');
      expect(f.monthYear(d), 'octubre 2026');
      expect(f.dayMonthYear(d), '15 oct 2026');
      expect(
        f.shortDateRange(d, DateTime(2026, 10, 19)),
        'jue 15 oct – lun 19 oct',
      );
    });
  });

  group('ISO 8601 helpers', () {
    test('toIsoDate pads and parseIso round-trips a date', () {
      expect(toIsoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(parseIso('2026-03-05'), DateTime(2026, 3, 5));
      expect(parseIso(''), isNull);
      expect(parseIso(null), isNull);
      expect(parseIso('no es una fecha'), isNull);
    });

    test('toIsoDateTime carries the local offset', () {
      final s = toIsoDateTime(DateTime(2026, 10, 15, 18, 30, 5));
      expect(s, matches(RegExp(r'^2026-10-15T18:30:05[+-]\d\d:\d\d$')));
    });

    test('shiftDays is calendar arithmetic across DST', () {
      // Europe/Madrid ends DST on 2026-10-25; calendar days stay midnight.
      expect(shiftDays(DateTime(2026, 10, 24), 1), DateTime(2026, 10, 25));
      expect(shiftDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
      expect(startOfWeek(DateTime(2026, 10, 15)), DateTime(2026, 10, 12));
      expect(
        isSameDay(DateTime(2026, 10, 15, 1), DateTime(2026, 10, 15, 23)),
        isTrue,
      );
    });
  });
}
