import 'package:apto_armas/core/format/percent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nbsp = ' ';

  group('formatPercent', () {
    test('formats a ratio with a non-breaking space before the sign', () {
      expect(formatPercent(0.87), '87$nbsp%');
      expect(formatPercent(0), '0$nbsp%');
      expect(formatPercent(1), '100$nbsp%');
      expect(formatPercent(0.5), '50$nbsp%');
    });

    test('the separator is a no-break space, not a normal one', () {
      final s = formatPercent(0.87);
      expect(s.codeUnitAt(2), 0x00A0);
      expect(s, isNot(contains(' ')));
    });

    test('rounds to the nearest whole percent, half up', () {
      expect(formatPercent(0.874), '87$nbsp%');
      expect(formatPercent(0.875), '88$nbsp%');
      expect(formatPercent(0.004), '0$nbsp%');
    });

    test('clamps out-of-range values and treats NaN as 0', () {
      expect(formatPercent(-0.2), '0$nbsp%');
      expect(formatPercent(1.7), '100$nbsp%');
      expect(formatPercent(double.nan), '0$nbsp%');
      expect(formatPercent(double.infinity), '100$nbsp%');
      expect(formatPercent(double.negativeInfinity), '0$nbsp%');
    });
  });
}
