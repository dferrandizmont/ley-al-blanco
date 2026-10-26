import 'package:apto_armas/core/format/edition_label.dart';
import 'package:apto_armas/features/mock/domain/mock_timer.dart';
import 'package:apto_armas/features/progress/domain/display_mastery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  group('displayMastery', () {
    test('chance level (1/3) starts the bar empty', () {
      expect(displayMastery(1 / 3), 0);
    });

    test('full mastery fills it', () {
      expect(displayMastery(1), 1);
    });

    test('is linear between chance and certainty', () {
      expect(displayMastery(2 / 3), closeTo(0.5, 1e-12));
      expect(displayMastery(0.5), closeTo(0.25, 1e-12));
      expect(displayMastery(0.8), closeTo((0.8 - 1 / 3) / (2 / 3), 1e-12));
    });

    test('clamps: below chance is empty, above 1 is full', () {
      expect(displayMastery(0), 0);
      expect(displayMastery(0.1), 0);
      expect(displayMastery(-3), 0);
      expect(displayMastery(1.7), 1);
    });

    test('NaN never reaches the screen', () {
      expect(displayMastery(double.nan), 0);
    });
  });

  group('mock countdown', () {
    final start = DateTime(2026, 10, 15, 18, 30);

    test('20 minutes at the start, counting down', () {
      expect(
        mockRemaining(startedAt: start, now: start),
        const Duration(minutes: 20),
      );
      expect(
        mockRemaining(
          startedAt: start,
          now: start.add(const Duration(minutes: 7, seconds: 5)),
        ),
        const Duration(minutes: 12, seconds: 55),
      );
    });

    test('never negative once the time is over', () {
      expect(
        mockRemaining(
          startedAt: start,
          now: start.add(const Duration(minutes: 45)),
        ),
        Duration.zero,
      );
    });

    test('formatCountdown: mm:ss, seconds round up', () {
      expect(formatCountdown(const Duration(minutes: 20)), '20:00');
      expect(formatCountdown(const Duration(minutes: 12, seconds: 5)), '12:05');
      expect(formatCountdown(const Duration(milliseconds: 100)), '00:01');
      expect(formatCountdown(Duration.zero), '00:00');
      expect(formatCountdown(const Duration(seconds: -4)), '00:00');
    });
  });

  group('editionLabel', () {
    setUpAll(() => initializeDateFormatting('es'));

    test('GC-2020-11 -> "GC nov-2020"', () {
      expect(editionLabel('GC-2020-11'), 'GC nov-2020');
    });

    test('other months and prefixes', () {
      expect(editionLabel('GC-2021-03'), 'GC mar-2021');
      expect(editionLabel('XX-2030-12'), 'XX dic-2030');
    });

    test('an id of another shape is returned unchanged', () {
      expect(editionLabel('edicion-especial'), 'edicion-especial');
      expect(editionLabel('GC-2020-13'), 'GC-2020-13');
    });
  });
}
