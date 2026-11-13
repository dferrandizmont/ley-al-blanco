import 'dart:math';

import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';

import '../../test/helpers.dart' show kTestNow;
import '../../test/support/study_support.dart' show attemptOn;

// Demo data of the App Store screenshots. Pure functions of the bank and the
// fixed clock, so the pictures are reproducible. No personal data: a made-up
// student.

/// Share of each tema's questions the made-up student has seen.
const Map<int, double> kDemoCoverage = {
  1: .97,
  2: .95,
  3: .93,
  4: .90,
  5: .88,
  6: .85,
  7: .82,
};

/// Number of questions in Fallos on the home and Fallos screens.
const int kDemoMistakes = 20;

/// A student on the way: every tema started, each seen question answered five
/// times over the last five days, plus [kDemoMistakes] questions whose last
/// answer is wrong (a few of them failed twice). Seeded `Random(11)`.
List<Attempt> demoProgress(List<Question> bank, {DateTime? now}) {
  final at = now ?? kTestNow;
  final rng = Random(11);
  final attempts = <Attempt>[];
  final seenByTema = <int, List<Question>>{};
  for (var tema = 1; tema <= 7; tema++) {
    final all = bank.where((q) => q.tema == tema).toList();
    final seen = all.take((all.length * kDemoCoverage[tema]!).ceil()).toList();
    seenByTema[tema] = seen;
    for (final q in seen) {
      final missedEarly = rng.nextDouble() < .10;
      for (final daysAgo in [5, 4, 3, 2, 1]) {
        attempts.add(
          attemptOn(
            q,
            correct: !(daysAgo == 5 && missedEarly),
            at: at.subtract(Duration(days: daysAgo)),
          ),
        );
      }
    }
  }
  // The mistakes: spread over the seven temas, newest first by hour.
  var picked = 0;
  for (var round = 0; picked < kDemoMistakes; round++) {
    for (var tema = 1; tema <= 7 && picked < kDemoMistakes; tema++) {
      final q =
          seenByTema[tema]![(round * 5 + tema * 3) % seenByTema[tema]!.length];
      final hours = 1 + picked;
      attempts.add(
        attemptOn(q, correct: false, at: at.subtract(Duration(hours: hours))),
      );
      if (picked % 4 == 0) {
        attempts.add(
          attemptOn(
            q,
            correct: false,
            at: at.subtract(Duration(hours: hours + 30)),
          ),
        );
      }
      picked++;
    }
  }
  return attempts;
}

/// Elapsed time of the mock of the result screen.
const Duration kDemoMockTime = Duration(minutes: 20, seconds: 31);

/// Practice question of the "explained" shot: answered, with the verdict, our
/// explanation and its article; no reform flag.
const String kDemoExplainedId = 't2-010';

/// Practice question of the "reform" shot: its official answer comes from a
/// repealed law, so the reform notice shows above the explanation.
const String kDemoReformId = 't5-010';
