import 'dart:math';

import 'package:apto_armas/features/mock/domain/mock_allocation.dart';
import 'package:apto_armas/features/mock/domain/mock_config.dart';
import 'package:apto_armas/features/progress/domain/pass_probability.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Spec §6: the pass probability (10,000 simulated mocks) takes < 100 ms on
/// the phone. Run on a REAL device, ideally in profile mode (AOT, like the
/// store build):
///
/// ```sh
/// flutter drive --profile -d <device> \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/probability_perf_test.dart
/// ```
///
/// `flutter test integration_test/probability_perf_test.dart -d <device>`
/// also works (debug, JIT: slower, so passing there is a stronger result).
/// Evidence goes to `docs/pruebas/`.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Questions per tema in GC-2020-11 (423 in all), as in questions.json.
  const temaSizes = {1: 68, 2: 67, 3: 66, 4: 70, 5: 66, 6: 64, 7: 22};
  final allocation = allocateByTema(temaSizes, MockConfig());

  Map<int, List<double>> profile(double Function(Random rng) p) {
    final rng = Random(7);
    return {
      for (final e in temaSizes.entries)
        e.key: List.generate(e.value, (_) => p(rng)),
    };
  }

  final profiles = <String, Map<int, List<double>>>{
    'new user (all 1/3)': profile((_) => 1 / 3),
    'mixed (uniform 0..1)': profile((rng) => rng.nextDouble()),
    'near the pass mark (0.6..0.95)': profile(
      (rng) => 0.6 + rng.nextDouble() * 0.35,
    ),
  };

  testWidgets('passProbability: 10,000 simulations under 100 ms', (_) async {
    const runs = 30;
    final report = <String, Object>{};
    for (final entry in profiles.entries) {
      // Warm-up (JIT / caches), not measured.
      passProbability(
        pByTema: entry.value,
        allocation: allocation,
        passMark: 16,
        rng: Random(42),
      );
      final times = <int>[];
      late double result;
      for (var i = 0; i < runs; i++) {
        final sw = Stopwatch()..start();
        result = passProbability(
          pByTema: entry.value,
          allocation: allocation,
          passMark: 16,
          rng: Random(42),
        );
        sw.stop();
        times.add(sw.elapsedMicroseconds);
      }
      times.sort();
      final median = times[runs ~/ 2] / 1000;
      final max = times.last / 1000;
      debugPrint(
        'PERF ${entry.key}: p=${result.toStringAsFixed(3)} '
        'median=${median.toStringAsFixed(2)} ms max=${max.toStringAsFixed(2)} ms '
        '(mode: ${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'})',
      );
      report[entry.key] = {'median_ms': median, 'max_ms': max, 'p': result};
      expect(max, lessThan(100), reason: entry.key);
    }
    binding.reportData = {'pass_probability': report};
  });
}
