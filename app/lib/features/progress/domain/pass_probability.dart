import 'dart:math' show Random;
import 'dart:typed_data';

/// Probability of passing a mock, by Monte Carlo (plan 2.7).
///
/// Each of [simulations] exams (default 10,000) draws `allocation[t]`
/// **distinct** questions per tema `t`, uniformly, from [pByTema]`[t]` (the
/// mastery `p` of each question of the tema, see `questionMastery`), exactly
/// like the mock generator's split; each drawn question is answered right
/// with its own `p`. Returns the fraction of exams with at least [passMark]
/// right answers.
///
/// Performance: the draw is a partial Fisher-Yates over one reusable index
/// buffer (it stays a permutation, so it never needs resetting), and the
/// `p` values live in a [Float64List]; the simulation loop allocates nothing.
/// The caller supplies [rng], so a fixed seed gives a stable result. It is
/// cheap enough to run on the UI isolate, but it is pure and can be wrapped
/// in `compute`.
///
/// Throws [ArgumentError] when [simulations] < 1, a `p` is outside 0..1, or
/// an allocated tema is missing from [pByTema] or has fewer questions than
/// requested.
double passProbability({
  required Map<int, List<double>> pByTema,
  required Map<int, int> allocation,
  required int passMark,
  required Random rng,
  int simulations = 10000,
}) {
  if (simulations < 1) {
    throw ArgumentError.value(simulations, 'simulations', 'must be >= 1');
  }
  final plan = _SimulationPlan.from(pByTema, allocation);

  var passed = 0;
  for (var sim = 0; sim < simulations; sim++) {
    if (plan.runExam(rng) >= passMark) passed++;
  }
  return passed / simulations;
}

/// Flattened, allocation-free representation of the exam being simulated.
class _SimulationPlan {
  _SimulationPlan._(
    this._probs,
    this._index,
    this._starts,
    this._lengths,
    this._takes,
  );

  factory _SimulationPlan.from(
    Map<int, List<double>> pByTema,
    Map<int, int> allocation,
  ) {
    final temas = [
      for (final entry in allocation.entries)
        if (entry.value > 0) entry.key,
    ]..sort();
    var total = 0;
    for (final tema in temas) {
      final probabilities = pByTema[tema];
      final take = allocation[tema]!;
      if (probabilities == null || probabilities.length < take) {
        throw ArgumentError.value(
          allocation,
          'allocation',
          'tema $tema needs $take questions, '
              'has ${probabilities?.length ?? 0}',
        );
      }
      total += probabilities.length;
    }
    final probs = Float64List(total);
    final index = Int32List(total);
    final starts = Int32List(temas.length);
    final lengths = Int32List(temas.length);
    final takes = Int32List(temas.length);
    var offset = 0;
    for (var t = 0; t < temas.length; t++) {
      final probabilities = pByTema[temas[t]]!;
      starts[t] = offset;
      lengths[t] = probabilities.length;
      takes[t] = allocation[temas[t]]!;
      for (var i = 0; i < probabilities.length; i++) {
        final p = probabilities[i];
        if (!(p >= 0 && p <= 1)) {
          throw ArgumentError.value(p, 'pByTema', 'p must be in 0..1');
        }
        probs[offset + i] = p;
        index[offset + i] = i;
      }
      offset += probabilities.length;
    }
    return _SimulationPlan._(probs, index, starts, lengths, takes);
  }

  final Float64List _probs;
  final Int32List _index;
  final Int32List _starts;
  final Int32List _lengths;
  final Int32List _takes;

  /// Simulates one exam and returns its number of right answers.
  int runExam(Random rng) {
    var correct = 0;
    for (var t = 0; t < _starts.length; t++) {
      final start = _starts[t];
      final length = _lengths[t];
      final take = _takes[t];
      for (var i = 0; i < take; i++) {
        final j = i + rng.nextInt(length - i);
        final picked = _index[start + j];
        _index[start + j] = _index[start + i];
        _index[start + i] = picked;
        if (rng.nextDouble() < _probs[start + picked]) correct++;
      }
    }
    return correct;
  }
}
