import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/progress/domain/mastery.dart';
import 'package:apto_armas/features/progress/domain/pass_probability.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

const realAllocation = {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1};

List<Question> loadBank() {
  final raw = File('assets/content/armas/GC-2020-11/questions.json')
      .readAsStringSync();
  return (jsonDecode(raw) as List)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList();
}

final now = DateTime.utc(2026, 10, 19, 12);

Attempt attempt(String id, bool correct, {int daysAgo = 0}) => Attempt(
  questionId: id,
  mode: AttemptMode.practice,
  selected: correct ? 0 : 1,
  correct: correct,
  answeredAt: now.subtract(Duration(days: daysAgo)),
);

Question q(String id, int tema) => Question(
  id: id,
  tema: tema,
  stem: 'Stem $id',
  options: const ['A', 'B', 'C'],
  answer: 0,
  edition: 'test',
);

/// P(X >= k) for X ~ Binomial(n, p), computed exactly.
double binomialTail(int n, double p, int k) {
  double choose(int n, int r) {
    var result = 1.0;
    for (var i = 1; i <= r; i++) {
      result = result * (n - r + i) / i;
    }
    return result;
  }

  var sum = 0.0;
  for (var x = k; x <= n; x++) {
    sum += choose(n, x) * pow(p, x) * pow(1 - p, n - x);
  }
  return sum;
}

/// Uniform `p` for every question of the real bank, by tema.
Map<int, List<double>> uniformP(List<Question> bank, double p) {
  final byTema = <int, List<double>>{};
  for (final question in bank) {
    byTema.putIfAbsent(question.tema, () => []).add(p);
  }
  return byTema;
}

void main() {
  group('questionMastery', () {
    double mastery(List<Attempt> attempts) =>
        questionMastery(attempts, now: now);

    test('no attempts gives the prior, 1/3', () {
      expect(mastery(const []), closeTo(1 / 3, 1e-12));
    });

    test('fresh evidence with the default prior', () {
      expect(mastery([attempt('q', true)]), closeTo(0.6667, 1e-3));
      expect(
        mastery([attempt('q', true), attempt('q', true)]),
        closeTo(0.7778, 1e-3),
      );
      expect(
        mastery([for (var i = 0; i < 3; i++) attempt('q', true)]),
        closeTo(0.8333, 1e-3),
      );
      expect(mastery([attempt('q', false)]), closeTo(0.1667, 1e-3));
    });

    test('matches the closed form exactly', () {
      expect(mastery([attempt('q', true)]), closeTo((1 / 3 + 1) / 2, 1e-12));
      expect(mastery([attempt('q', false)]), closeTo((1 / 3) / 2, 1e-12));
    });

    test('mixed fresh attempts', () {
      final p = mastery([
        attempt('q', true),
        attempt('q', false),
        attempt('q', true),
      ]);
      expect(p, closeTo((1 / 3 + 2) / 4, 1e-12));
    });

    test('an attempt one half-life old weighs half', () {
      final p = mastery([attempt('q', true, daysAgo: 14)]);
      expect(p, closeTo((1 / 3 + 0.5) / 1.5, 1e-12));
    });

    test('two half-lives weigh a quarter', () {
      final p = mastery([attempt('q', true, daysAgo: 28)]);
      expect(p, closeTo((1 / 3 + 0.25) / 1.25, 1e-12));
    });

    test('old evidence decays towards 1/3', () {
      final fresh = mastery([attempt('q', true)]);
      final month = mastery([attempt('q', true, daysAgo: 30)]);
      final year = mastery([attempt('q', true, daysAgo: 365)]);
      expect(fresh, greaterThan(month));
      expect(month, greaterThan(year));
      expect(year, closeTo(1 / 3, 1e-4));
      // Same for a wrong answer: it climbs back to 1/3.
      final oldWrong = mastery([attempt('q', false, daysAgo: 365)]);
      expect(oldWrong, closeTo(1 / 3, 1e-4));
      expect(oldWrong, greaterThan(mastery([attempt('q', false)])));
    });

    test('recent attempts outweigh old ones', () {
      final improving = mastery([
        attempt('q', false, daysAgo: 30),
        attempt('q', true),
      ]);
      final worsening = mastery([
        attempt('q', true, daysAgo: 30),
        attempt('q', false),
      ]);
      expect(improving, greaterThan(worsening));
    });

    test('the order of the attempts does not matter', () {
      final list = [
        attempt('q', true, daysAgo: 5),
        attempt('q', false, daysAgo: 1),
        attempt('q', true, daysAgo: 20),
      ];
      expect(mastery(list), closeTo(mastery(list.reversed.toList()), 1e-12));
    });

    test('an attempt dated in the future counts as fresh', () {
      final future = Attempt(
        questionId: 'q',
        mode: AttemptMode.practice,
        selected: 0,
        correct: true,
        answeredAt: now.add(const Duration(days: 3)),
      );
      expect(mastery([future]), closeTo(mastery([attempt('q', true)]), 1e-12));
    });

    test('a custom model changes the prior and the half-life', () {
      const model = MasteryModel(
        priorMean: 0.5,
        priorStrength: 2,
        halfLifeDays: 7,
      );
      expect(
        questionMastery(const [], now: now, model: model),
        closeTo(0.5, 1e-12),
      );
      final p = questionMastery(
        [attempt('q', true, daysAgo: 7)],
        now: now,
        model: model,
      );
      // a0 = 1, b0 = 1, w = 0.5 -> (1 + 0.5) / (2 + 0.5)
      expect(p, closeTo(0.6, 1e-12));
    });

    test('always stays inside 0..1', () {
      final rng = Random(1);
      for (var i = 0; i < 200; i++) {
        final p = mastery([
          for (var j = 0; j < rng.nextInt(30); j++)
            attempt('q', rng.nextBool(), daysAgo: rng.nextInt(400)),
        ]);
        expect(p, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('masteryById / temaMastery / coverage', () {
    final questions = [
      q('a1', 1),
      q('a2', 1),
      q('a3', 1),
      q('a4', 1),
      q('b1', 2),
    ];
    final attempts = [
      attempt('a1', true),
      attempt('a1', true),
      attempt('a2', false),
      attempt('retired', true),
    ];

    test('masteryById covers every question and ignores retired ids', () {
      final byId = masteryById(
        questions: questions,
        attempts: attempts,
        now: now,
      );
      expect(byId.keys, ['a1', 'a2', 'a3', 'a4', 'b1']);
      expect(byId['a1'], closeTo(0.7778, 1e-3));
      expect(byId['a2'], closeTo(0.1667, 1e-3));
      expect(byId['a3'], closeTo(1 / 3, 1e-12));
    });

    test('temaMastery averages all questions, unseen at the prior', () {
      final byId = masteryById(
        questions: questions,
        attempts: attempts,
        now: now,
      );
      final tema = temaMastery(questions, byId);
      expect(tema[1], closeTo((0.77778 + 0.16667 + 1 / 3 + 1 / 3) / 4, 1e-4));
      expect(tema[2], closeTo(1 / 3, 1e-12));
      expect(tema.keys, [1, 2]);
    });

    test('temaMastery treats ids missing from the map as unseen', () {
      final tema = temaMastery(questions, {'a1': 1.0});
      expect(tema[1], closeTo((1.0 + 3 / 3) / 4, 1e-12));
      expect(tema[2], closeTo(1 / 3, 1e-12));
    });

    test('coverage is the fraction of questions seen per tema', () {
      final c = coverage(questions, attempts);
      expect(c[1], closeTo(0.5, 1e-12));
      expect(c[2], 0.0);
    });

    test('coverage reaches 1.0 when everything was seen', () {
      final c = coverage(questions, [
        for (final x in questions) attempt(x.id, true),
      ]);
      expect(c, {1: 1.0, 2: 1.0});
    });
  });

  group('passProbability', () {
    final bank = loadBank();

    double probability(
      Map<int, List<double>> p, {
      Map<int, int> allocation = realAllocation,
      int passMark = 16,
      int seed = 1,
      int simulations = 10000,
    }) => passProbability(
      pByTema: p,
      allocation: allocation,
      passMark: passMark,
      rng: Random(seed),
      simulations: simulations,
    );

    test('everything mastered (p = 1) passes always', () {
      expect(probability(uniformP(bank, 1.0)), 1.0);
    });

    test('pure guessing (p = 1/3) practically never passes', () {
      expect(probability(uniformP(bank, 1 / 3)), lessThan(0.001));
    });

    test('nothing known (p = 0) never passes', () {
      expect(probability(uniformP(bank, 0.0)), 0.0);
    });

    test('p = 0.8 matches the exact binomial tail within 1.5 points', () {
      final exact = binomialTail(20, 0.8, 16);
      expect(exact, closeTo(0.6296, 1e-3));
      expect(probability(uniformP(bank, 0.8)), closeTo(exact, 0.015));
    });

    test('p = 0.5 matches the binomial tail too', () {
      final exact = binomialTail(20, 0.5, 16);
      expect(
        probability(uniformP(bank, 0.5), simulations: 200000),
        closeTo(exact, 0.003),
      );
    });

    test('a fixed seed gives an identical result', () {
      final p = uniformP(bank, 0.8);
      expect(probability(p, seed: 42), probability(p, seed: 42));
    });

    test('the passMark moves the result the right way', () {
      final p = uniformP(bank, 0.8);
      expect(probability(p, passMark: 12), greaterThan(probability(p)));
      expect(probability(p, passMark: 19), lessThan(probability(p)));
      expect(probability(p, passMark: 0), 1.0);
      expect(probability(p, passMark: 21), 0.0);
    });

    test('4 sure failures can still pass; 5 never can', () {
      Map<int, List<double>> withBadTema() => {
        1: List.filled(10, 0.0),
        2: List.filled(30, 1.0),
      };
      // 4 + 16 draws: at most 16 right -> always passes with 16.
      expect(probability(withBadTema(), allocation: {1: 4, 2: 16}), 1.0);
      // 5 + 15 draws: at most 15 right -> never passes.
      expect(probability(withBadTema(), allocation: {1: 5, 2: 15}), 0.0);
    });

    test('a tema at 0 with a single question does not stop a pass', () {
      final p = {for (var t = 1; t <= 7; t++) t: List<double>.filled(20, 1.0)};
      p[7] = List.filled(20, 0.0);
      expect(probability(p, allocation: realAllocation), 1.0);
    });

    test('draws are without replacement and uniform (hypergeometric)', () {
      // 10 questions: 5 sure, 5 impossible; draw 2. Pass needs both sure.
      final p = {
        1: [1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      };
      // C(5,2) / C(10,2) = 10 / 45
      expect(
        probability(p, allocation: {1: 2}, passMark: 2, simulations: 100000),
        closeTo(10 / 45, 0.01),
      );
      // at least one sure: 1 - 10/45
      expect(
        probability(p, allocation: {1: 2}, passMark: 1, simulations: 100000),
        closeTo(35 / 45, 0.01),
      );
    });

    test('drawing the whole tema is deterministic', () {
      final p = {
        1: [1.0, 1.0, 0.0],
      };
      expect(probability(p, allocation: {1: 3}, passMark: 2), 1.0);
      expect(probability(p, allocation: {1: 3}, passMark: 3), 0.0);
    });

    test('a coin-flip question decides a borderline exam', () {
      final p = {
        1: List<double>.filled(4, 0.5),
        2: List<double>.filled(30, 1.0),
      };
      expect(
        probability(
          p,
          allocation: {1: 1, 2: 19},
          passMark: 20,
          simulations: 50000,
        ),
        closeTo(0.5, 0.01),
      );
    });

    test('temas with allocation 0 or no entry are skipped', () {
      final p = {
        1: List<double>.filled(30, 1.0),
        2: List<double>.filled(5, 0.0),
      };
      expect(probability(p, allocation: {1: 20, 2: 0}), 1.0);
    });

    test('invalid input is rejected', () {
      expect(
        () => probability(
          {
            1: [1.0],
          },
          allocation: {1: 2},
        ),
        throwsArgumentError,
      );
      expect(
        () => probability(
          {
            1: [1.0],
          },
          allocation: {2: 1},
        ),
        throwsArgumentError,
      );
      expect(
        () => probability(
          {
            1: [1.5],
          },
          allocation: {1: 1},
        ),
        throwsArgumentError,
      );
      expect(
        () => probability(
          {
            1: [double.nan],
          },
          allocation: {1: 1},
        ),
        throwsArgumentError,
      );
      expect(
        () => probability(uniformP(bank, 1.0), simulations: 0),
        throwsArgumentError,
      );
    });

    test('benchmark: 10,000 exams over the real bank', () {
      final rng = Random(3);
      final p = {
        for (final entry in uniformP(bank, 0).entries)
          entry.key: [for (final _ in entry.value) rng.nextDouble()],
      };
      // warm-up so the JIT does not dominate the measurement
      probability(p, simulations: 500);
      final watch = Stopwatch()..start();
      final result = probability(p);
      watch.stop();
      // ignore: avoid_print
      print(
        'passProbability: 10,000 exams over ${bank.length} questions '
        'in ${watch.elapsedMilliseconds} ms (p = $result)',
      );
      expect(watch.elapsedMilliseconds, lessThan(1500));
      expect(result, inInclusiveRange(0.0, 1.0));
    });
  });
}
