import 'package:apto_armas/core/format/elapsed_time.dart';
import 'package:apto_armas/l10n/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEs();

  group('formatElapsedTime', () {
    test('formatea cero segundos', () {
      expect(formatElapsedTime(Duration.zero, l10n), '0 min 0 s');
    });

    test('formatea una duración inferior a un minuto', () {
      expect(
        formatElapsedTime(const Duration(seconds: 59), l10n),
        '0 min 59 s',
      );
    });

    test('formatea un minuto exacto', () {
      expect(formatElapsedTime(const Duration(seconds: 60), l10n), '1 min 0 s');
    });

    test('formatea minutos y segundos', () {
      expect(
        formatElapsedTime(const Duration(minutes: 14, seconds: 32), l10n),
        '14 min 32 s',
      );
    });

    test('conserva las duraciones superiores a veinte minutos', () {
      expect(
        formatElapsedTime(const Duration(minutes: 20, seconds: 1), l10n),
        '20 min 1 s',
      );
    });

    test('conserva los minutos totales por encima de una hora', () {
      expect(
        formatElapsedTime(const Duration(minutes: 90, seconds: 32), l10n),
        '90 min 32 s',
      );
    });

    test('trunca las fracciones de segundo sin redondear', () {
      expect(
        formatElapsedTime(const Duration(milliseconds: 999), l10n),
        '0 min 0 s',
      );
      expect(
        formatElapsedTime(const Duration(seconds: 59, milliseconds: 999), l10n),
        '0 min 59 s',
      );
      expect(
        formatElapsedTime(
          const Duration(minutes: 14, seconds: 32, milliseconds: 999),
          l10n,
        ),
        '14 min 32 s',
      );
    });
  });
}
