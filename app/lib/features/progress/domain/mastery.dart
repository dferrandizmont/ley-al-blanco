import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import '../../content/domain/question.dart';
import '../../quiz/domain/attempt.dart';

/// Parameters of the per-question mastery estimate (plan 2.7).
@immutable
class MasteryModel {
  const MasteryModel({
    this.priorMean = 1 / 3,
    this.priorStrength = 1.0,
    this.halfLifeDays = 14,
  }) : assert(priorMean > 0 && priorMean < 1),
       assert(priorStrength > 0),
       assert(halfLifeDays > 0);

  /// Mastery of a question never seen: chance with 3 options, a deliberately
  /// conservative start.
  final double priorMean;

  /// Weight of the prior, in "equivalent attempts".
  final double priorStrength;

  /// Days after which an attempt counts half as much.
  final double halfLifeDays;

  double get alpha0 => priorMean * priorStrength;
  double get beta0 => (1 - priorMean) * priorStrength;

  @override
  bool operator ==(Object other) =>
      other is MasteryModel &&
      other.priorMean == priorMean &&
      other.priorStrength == priorStrength &&
      other.halfLifeDays == halfLifeDays;

  @override
  int get hashCode => Object.hash(priorMean, priorStrength, halfLifeDays);
}

/// Estimated probability `p` of answering a question right (plan 2.7):
/// a Beta-Bernoulli posterior mean with time decay.
///
/// Prior `Beta(a0, b0)` with `a0 = priorMean * priorStrength` and
/// `b0 = (1 - priorMean) * priorStrength`. An attempt of age `d` days has
/// weight `w = 0.5 ^ (d / halfLifeDays)` (a future timestamp counts as age
/// 0), and
/// `p = (a0 + sum(w * correct)) / (a0 + b0 + sum(w))`.
///
/// With the defaults and fresh attempts: none -> 0.333, one right -> 0.667,
/// two -> 0.778, three -> 0.833, one wrong -> 0.167; as the evidence ages,
/// `p` drifts back to the prior. [attemptsForQuestion] must already be
/// filtered to one question; the order does not matter.
double questionMastery(
  Iterable<Attempt> attemptsForQuestion, {
  required DateTime now,
  MasteryModel model = const MasteryModel(),
}) {
  var weightedCorrect = 0.0;
  var weightSum = 0.0;
  for (final attempt in attemptsForQuestion) {
    final weight = _weight(attempt.answeredAt, now, model.halfLifeDays);
    weightSum += weight;
    if (attempt.correct) weightedCorrect += weight;
  }
  return (model.alpha0 + weightedCorrect) /
      (model.alpha0 + model.beta0 + weightSum);
}

double _weight(DateTime answeredAt, DateTime now, double halfLifeDays) {
  final ageDays = now.difference(answeredAt).inMicroseconds / _microsPerDay;
  if (ageDays <= 0) return 1.0;
  return math.pow(0.5, ageDays / halfLifeDays).toDouble();
}

const _microsPerDay = 24 * 60 * 60 * 1000000;

/// Mastery of every question in [questions] (id -> `p`). Questions without
/// attempts get the prior; attempts of ids not in [questions] (retired) are
/// ignored.
Map<String, double> masteryById({
  required Iterable<Question> questions,
  required Iterable<Attempt> attempts,
  required DateTime now,
  MasteryModel model = const MasteryModel(),
}) {
  final byQuestion = <String, List<Attempt>>{};
  for (final attempt in attempts) {
    byQuestion.putIfAbsent(attempt.questionId, () => []).add(attempt);
  }
  return {
    for (final question in questions)
      question.id: questionMastery(
        byQuestion[question.id] ?? const <Attempt>[],
        now: now,
        model: model,
      ),
  };
}

/// Mastery per tema: the mean of `p` over **all** its questions, those not
/// in [masteryById] (never seen) counting at [unseen] (the prior, 1/3 by
/// default). Ascending by tema.
Map<int, double> temaMastery(
  Iterable<Question> questions,
  Map<String, double> masteryById, {
  double unseen = 1 / 3,
}) {
  final sums = <int, double>{};
  final counts = <int, int>{};
  for (final question in questions) {
    sums[question.tema] =
        (sums[question.tema] ?? 0) + (masteryById[question.id] ?? unseen);
    counts[question.tema] = (counts[question.tema] ?? 0) + 1;
  }
  final temas = counts.keys.toList()..sort();
  return {for (final tema in temas) tema: sums[tema]! / counts[tema]!};
}

/// Per tema, the fraction (0..1) of its questions with at least one attempt.
/// Ascending by tema; attempts of ids not in [questions] are ignored.
Map<int, double> coverage(
  Iterable<Question> questions,
  Iterable<Attempt> attempts,
) {
  final seen = {for (final attempt in attempts) attempt.questionId};
  final seenCount = <int, int>{};
  final counts = <int, int>{};
  for (final question in questions) {
    counts[question.tema] = (counts[question.tema] ?? 0) + 1;
    if (seen.contains(question.id)) {
      seenCount[question.tema] = (seenCount[question.tema] ?? 0) + 1;
    }
  }
  final temas = counts.keys.toList()..sort();
  return {
    for (final tema in temas) tema: (seenCount[tema] ?? 0) / counts[tema]!,
  };
}
