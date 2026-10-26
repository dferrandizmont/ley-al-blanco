import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../content/application/content_providers.dart';
import '../../mistakes/application/mistakes_providers.dart';
import '../../mock/application/mock_providers.dart';
import '../../mock/domain/mock_allocation.dart';
import '../../quiz/application/quiz_providers.dart';
import '../domain/mastery.dart';
import '../domain/pass_probability.dart';

/// `p` (estimated chance of answering right) per active question.
final masteryByIdProvider = FutureProvider<Map<String, double>>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final attempts = await ref.watch(attemptsProvider.future);
  final now = ref.watch(clockProvider)();
  return masteryById(questions: questions, attempts: attempts, now: now);
});

/// Mean `p` per tema (ascending by tema).
final temaMasteryProvider = FutureProvider<Map<int, double>>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final byId = await ref.watch(masteryByIdProvider.future);
  return temaMastery(questions, byId);
});

/// Fraction (0..1) of each tema's questions with at least one attempt.
final coverageProvider = FutureProvider<Map<int, double>>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final attempts = await ref.watch(attemptsProvider.future);
  return coverage(questions, attempts);
});

/// Chance (0..1) of passing a mock today, by Monte Carlo over the current
/// mastery (plan 2.7).
///
/// Runs synchronously on the UI isolate: 10,000 simulations cost ~10 ms
/// (benchmarked), well below what an isolate round trip is worth, so there is
/// no `compute`. The random source is seeded with a constant, so the same
/// data always gives the same number and the ring does not flicker between
/// rebuilds.
final passProbabilityProvider = FutureProvider<double>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final masteryById = await ref.watch(masteryByIdProvider.future);
  final config = await ref.watch(mockConfigProvider.future);

  final pByTema = <int, List<double>>{};
  for (final question in questions) {
    pByTema
        .putIfAbsent(question.tema, () => [])
        .add(masteryById[question.id] ?? 1 / 3);
  }
  final allocation = allocateByTema({
    for (final entry in pByTema.entries) entry.key: entry.value.length,
  }, config);
  return passProbability(
    pByTema: pByTema,
    allocation: allocation,
    passMark: config.passMark,
    rng: Random(42),
  );
});

/// What the home screen shows per tema.
@immutable
class TemaSummary {
  const TemaSummary({
    required this.tema,
    required this.questionCount,
    required this.mastery,
    required this.coverage,
    required this.mistakesCount,
  });

  final int tema;
  final int questionCount;

  /// Mean `p`, 0..1.
  final double mastery;

  /// Fraction of the tema's questions already attempted, 0..1.
  final double coverage;

  /// Questions of the tema currently in Fallos.
  final int mistakesCount;

  @override
  bool operator ==(Object other) =>
      other is TemaSummary &&
      other.tema == tema &&
      other.questionCount == questionCount &&
      other.mastery == mastery &&
      other.coverage == coverage &&
      other.mistakesCount == mistakesCount;

  @override
  int get hashCode =>
      Object.hash(tema, questionCount, mastery, coverage, mistakesCount);

  @override
  String toString() =>
      'TemaSummary($tema: $questionCount q, mastery: $mastery, '
      'coverage: $coverage, mistakes: $mistakesCount)';
}

/// One [TemaSummary] per tema, ascending.
final temaSummaryProvider = FutureProvider<List<TemaSummary>>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final mastery = await ref.watch(temaMasteryProvider.future);
  final covered = await ref.watch(coverageProvider.future);
  final fallos = await ref.watch(mistakesProvider(null).future);
  final temaById = await ref.watch(temaByIdProvider.future);

  final counts = <int, int>{};
  for (final question in questions) {
    counts[question.tema] = (counts[question.tema] ?? 0) + 1;
  }
  final mistakesByTema = <int, int>{};
  for (final entry in fallos) {
    final tema = temaById[entry.questionId]!;
    mistakesByTema[tema] = (mistakesByTema[tema] ?? 0) + 1;
  }
  final temas = counts.keys.toList()..sort();
  return [
    for (final tema in temas)
      TemaSummary(
        tema: tema,
        questionCount: counts[tema]!,
        mastery: mastery[tema] ?? 0,
        coverage: covered[tema] ?? 0,
        mistakesCount: mistakesByTema[tema] ?? 0,
      ),
  ];
});
