import 'package:integration_test/integration_test_driver.dart';

/// Host side of `flutter drive` for the integration tests (prints and saves
/// `binding.reportData`, e.g. the timings of `probability_perf_test.dart`).
Future<void> main() => integrationDriver();
