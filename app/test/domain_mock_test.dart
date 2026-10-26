import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/content/domain/same_stem_groups.dart';
import 'package:apto_armas/features/mock/domain/mock_allocation.dart';
import 'package:apto_armas/features/mock/domain/mock_config.dart';
import 'package:apto_armas/features/mock/domain/mock_generator.dart';
import 'package:apto_armas/features/mock/domain/mock_result.dart';
import 'package:flutter_test/flutter_test.dart';

const realSizes = {1: 68, 2: 67, 3: 66, 4: 70, 5: 66, 6: 64, 7: 22};

List<Question> loadBank() {
  final raw = File('assets/content/armas/GC-2020-11/questions.json')
      .readAsStringSync();
  return (jsonDecode(raw) as List)
      .map((e) => Question.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Question with id `t<tema>-<n>` whose official answer is option 0.
Question q(int tema, int n, {int answer = 0}) => Question(
  id: 't$tema-${n.toString().padLeft(3, '0')}',
  tema: tema,
  stem: 'Stem $tema-$n',
  options: const ['A', 'B', 'C'],
  answer: answer,
  edition: 'test',
);

/// A bank with `perTema[t]` questions in tema `t`.
List<Question> bankOf(Map<int, int> perTema) => [
  for (final e in perTema.entries)
    for (var n = 1; n <= e.value; n++) q(e.key, n),
];

Map<int, int> countByTema(List<Question> mock) {
  final counts = <int, int>{};
  for (final question in mock) {
    counts[question.tema] = (counts[question.tema] ?? 0) + 1;
  }
  return counts;
}

List<String> ids(List<Question> mock) => [for (final x in mock) x.id];

void main() {
  group('MockConfig', () {
    test('defaults are 20 / 16 / proportional / avoid 2', () {
      final c = MockConfig();
      expect(c.size, 20);
      expect(c.passMark, 16);
      expect(c.distribution, isNull);
      expect(c.avoidLastMocks, 2);
    });

    test('fromJson reads manifest keys', () {
      final c = MockConfig.fromJson({
        'size': 20,
        'pass_mark': 16,
        'distribution': {
          '1': 3,
          '2': 3,
          '3': 3,
          '4': 4,
          '5': 3,
          '6': 3,
          '7': 1,
        },
        'avoid_last_mocks': 3,
      });
      expect(c.distribution, {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1});
      expect(c.avoidLastMocks, 3);
    });

    test('fromJson with no keys gives the defaults', () {
      expect(MockConfig.fromJson({}), MockConfig());
    });

    test('equal configs are == (distribution compared by content)', () {
      expect(
        MockConfig(size: 4, passMark: 3, distribution: {1: 2, 2: 2}),
        MockConfig(size: 4, passMark: 3, distribution: {2: 2, 1: 2}),
      );
      expect(
        MockConfig(size: 4, passMark: 3, distribution: {1: 2, 2: 2}).hashCode,
        MockConfig(size: 4, passMark: 3, distribution: {2: 2, 1: 2}).hashCode,
      );
      expect(MockConfig(), isNot(MockConfig(passMark: 15)));
    });

    test('distribution must add up to size', () {
      expect(
        () => MockConfig(size: 20, distribution: {1: 10, 2: 9}),
        throwsArgumentError,
      );
      expect(
        () => MockConfig.fromJson({
          'distribution': {'1': 21},
        }),
        throwsArgumentError,
      );
    });

    test('rejects nonsense values', () {
      expect(() => MockConfig(size: 0), throwsArgumentError);
      expect(() => MockConfig(passMark: 0), throwsArgumentError);
      expect(
        () => MockConfig(size: 10),
        throwsArgumentError,
        reason: '16 > 10',
      );
      expect(() => MockConfig(avoidLastMocks: -1), throwsArgumentError);
      expect(
        () => MockConfig(size: 2, passMark: 1, distribution: {1: -1, 2: 3}),
        throwsArgumentError,
      );
    });

    test('distribution is unmodifiable', () {
      final c = MockConfig(size: 2, passMark: 1, distribution: {1: 2});
      expect(() => c.distribution![1] = 1, throwsUnsupportedError);
    });
  });

  group('allocateByTema', () {
    test('real bank gives 3/3/3/4/3/3/1', () {
      final a = allocateByTema(realSizes, MockConfig());
      expect(a, {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1});
      expect(a.values.reduce((x, y) => x + y), 20);
    });

    test('result does not depend on map insertion order', () {
      final reversed = {
        for (final k in realSizes.keys.toList().reversed) k: realSizes[k]!,
      };
      expect(allocateByTema(reversed, MockConfig()), {
        1: 3,
        2: 3,
        3: 3,
        4: 4,
        5: 3,
        6: 3,
        7: 1,
      });
    });

    test('uses the configured distribution when set', () {
      final config = MockConfig(distribution: {1: 5, 2: 5, 3: 5, 4: 5});
      final a = allocateByTema(realSizes, config);
      expect(a, {1: 5, 2: 5, 3: 5, 4: 5, 5: 0, 6: 0, 7: 0});
    });

    test('a distribution needing more than a tema has is an error', () {
      final config = MockConfig(distribution: {2: 20});
      expect(() => allocateByTema({1: 30, 2: 5}, config), throwsArgumentError);
    });

    test('a distribution for a tema that does not exist is an error', () {
      final config = MockConfig(distribution: {9: 20});
      expect(() => allocateByTema(realSizes, config), throwsArgumentError);
    });

    test(
      'ties: equal remainders go to the larger tema, then the lower number',
      () {
        // total 10, size 4: quotas 0.4 / 2.4 / 1.2 -> floors 0/2/1, one seat
        // left; remainders 4/4/2 tie between tema 1 (size 1) and tema 2 (6).
        final bySize = allocateByTema({
          1: 1,
          2: 6,
          3: 3,
        }, MockConfig(size: 4, passMark: 3));
        expect(bySize, {1: 0, 2: 3, 3: 1});

        // three equal temas, size 20: 6.67 each, two seats left, all remainders
        // and sizes tie -> the lowest tema numbers win.
        final byNumber = allocateByTema({1: 10, 2: 10, 3: 10}, MockConfig());
        expect(byNumber, {1: 7, 2: 7, 3: 6});
      },
    );

    test('larger remainder beats larger size', () {
      // total 12, size 5: quotas 0.42 / 3.33 / 1.25 -> floors 0/3/1, one seat
      // left; the biggest remainder is tema 1's even though it is the
      // smallest tema.
      final a = allocateByTema({
        1: 1,
        2: 8,
        3: 3,
      }, MockConfig(size: 5, passMark: 4));
      expect(a, {1: 1, 2: 3, 3: 1});
    });

    test('always sums to size and never exceeds a tema (random banks)', () {
      final rng = Random(42);
      for (var run = 0; run < 500; run++) {
        final temas = 1 + rng.nextInt(8);
        final sizes = {for (var t = 1; t <= temas; t++) t: rng.nextInt(80)};
        final total = sizes.values.fold(0, (a, b) => a + b);
        if (total == 0) continue;
        final size = 1 + rng.nextInt(min(total, 40));
        final a = allocateByTema(sizes, MockConfig(size: size, passMark: 1));
        expect(a.values.fold(0, (x, y) => x + y), size, reason: '$sizes');
        for (final t in sizes.keys) {
          expect(a[t], inInclusiveRange(0, sizes[t]!), reason: '$sizes $a');
        }
      }
    });

    test('size equal to the whole bank takes everything', () {
      final a = allocateByTema({1: 3, 2: 2}, MockConfig(size: 5, passMark: 4));
      expect(a, {1: 3, 2: 2});
    });

    test('a single tema gets everything', () {
      expect(allocateByTema({3: 50}, MockConfig()), {3: 20});
    });

    test('empty temas are tolerated', () {
      final a = allocateByTema({1: 0, 2: 30}, MockConfig());
      expect(a, {1: 0, 2: 20});
    });

    test('size bigger than the bank is an error', () {
      expect(
        () => allocateByTema({1: 10, 2: 9}, MockConfig()),
        throwsArgumentError,
      );
      expect(() => allocateByTema({}, MockConfig()), throwsArgumentError);
    });

    test('negative sizes are an error', () {
      expect(
        () => allocateByTema({1: -1, 2: 40}, MockConfig()),
        throwsArgumentError,
      );
    });
  });

  group('generateMock', () {
    final bank = loadBank();
    final groups = sameStemGroups(bank);

    List<Question> generate(
      int seed, {
      List<List<String>> recent = const [],
      List<Question>? questions,
      MockConfig? config,
      List<Set<String>>? exclusion,
    }) => generateMock(
      questions: questions ?? bank,
      config: config ?? MockConfig(),
      rng: Random(seed),
      recentMocks: recent,
      exclusionGroups: exclusion ?? groups,
    );

    test('has 20 questions with the 3/3/3/4/3/3/1 split, ordered by tema', () {
      final mock = generate(1);
      expect(mock, hasLength(20));
      expect(countByTema(mock), {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1});
      final temas = mock.map((x) => x.tema).toList();
      expect(temas, [...temas]..sort());
      expect(ids(mock).toSet(), hasLength(20), reason: 'no repeats');
    });

    test(
      'the same seed gives the same mock, even if the bank order changes',
      () {
        expect(ids(generate(7)), ids(generate(7)));
        expect(
          ids(generate(7)),
          ids(generate(7, questions: bank.reversed.toList())),
        );
      },
    );

    test('different seeds give different mocks', () {
      final mocks = {for (var s = 0; s < 10; s++) ids(generate(s)).join(',')};
      expect(mocks.length, greaterThan(8));
    });

    test('respects a configured distribution', () {
      final config = MockConfig(distribution: {1: 10, 4: 5, 7: 5});
      final mock = generate(3, config: config);
      expect(countByTema(mock), {1: 10, 4: 5, 7: 5});
    });

    test('order inside a tema is random, not the bank order', () {
      final orders = {
        for (var s = 0; s < 20; s++) ids(generate(s)).take(3).join(','),
      };
      expect(orders.length, greaterThan(1));
    });

    test('avoids the questions of the last 2 mocks (bank is big enough)', () {
      for (var seed = 0; seed < 200; seed++) {
        final first = ids(generate(seed));
        final second = ids(generate(seed + 1000, recent: [first]));
        final third = ids(generate(seed + 2000, recent: [second, first]));
        expect(second.toSet().intersection(first.toSet()), isEmpty);
        expect(third.toSet().intersection(first.toSet()), isEmpty);
        expect(third.toSet().intersection(second.toSet()), isEmpty);
      }
    });

    test('only the last avoidLastMocks mocks are avoided', () {
      final tema7 = bank.where((x) => x.tema == 7).map((x) => x.id).toList();
      final newest = [tema7[0]];
      final z = tema7[1];
      final older = tema7.skip(2).toList(); // 20 ids
      final recent = [newest, older];

      // Avoiding 2 mocks: only z is fresh, so tema 7 always yields z.
      for (var seed = 0; seed < 100; seed++) {
        final mock = generate(seed, recent: recent);
        expect(mock.singleWhere((x) => x.tema == 7).id, z);
      }
      // Avoiding 1 mock: the older mock no longer counts, so its ids are
      // fresh again (and the newest one is still avoided).
      final config = MockConfig(avoidLastMocks: 1);
      final picked = {
        for (var seed = 0; seed < 100; seed++)
          generate(
            seed,
            config: config,
            recent: recent,
          ).singleWhere((x) => x.tema == 7).id,
      };
      expect(picked, isNot(contains(newest.single)));
      expect(picked.intersection(older.toSet()), isNotEmpty);
    });

    test('with avoidLastMocks 0 nothing is avoided', () {
      final config = MockConfig(avoidLastMocks: 0);
      final all = bank.map((x) => x.id).toList();
      expect(() => generate(1, config: config, recent: [all]), returnsNormally);
    });

    test('falls back to the least recently used when fresh ones run out', () {
      // tema 1: a1..a6, tema 2: b1..b4. size 5 -> 3 + 2.
      final small = bankOf({1: 6, 2: 4});
      final config = MockConfig(size: 5, passMark: 4);
      final newest = ['t1-001', 't1-002'];
      final oldest = ['t1-003', 't1-004'];
      for (var seed = 0; seed < 100; seed++) {
        final mock = generate(
          seed,
          questions: small,
          config: config,
          recent: [newest, oldest],
          exclusion: const [],
        );
        final tema1 = mock.where((x) => x.tema == 1).map((x) => x.id).toSet();
        // 2 fresh (t1-005, t1-006) + 1 from the OLDEST recent mock.
        expect(tema1, containsAll(['t1-005', 't1-006']));
        expect(tema1.intersection({'t1-003', 't1-004'}), hasLength(1));
        expect(tema1.intersection({'t1-001', 't1-002'}), isEmpty);
      }
    });

    test('fallback takes the oldest mock first, then the newer one', () {
      final small = bankOf({1: 4});
      final config = MockConfig(size: 3, passMark: 2);
      final mock = generate(
        5,
        questions: small,
        config: config,
        recent: [
          ['t1-001'], // newest
          ['t1-002'], // oldest
        ],
        exclusion: const [],
      );
      // 2 fresh (t1-003, t1-004), then the oldest used one: t1-002.
      expect(ids(mock).toSet(), {'t1-002', 't1-003', 't1-004'});
    });

    test('ids of retired questions in recent mocks are ignored', () {
      final mock = generate(
        1,
        recent: [
          ['gone-1', 'gone-2'],
        ],
      );
      expect(mock, hasLength(20));
    });

    test('never two questions of the same exclusion group (1,000 seeds)', () {
      for (var seed = 0; seed < 1000; seed++) {
        final chosen = ids(generate(seed)).toSet();
        for (final group in groups) {
          expect(
            chosen.intersection(group).length,
            lessThanOrEqualTo(1),
            reason: 'seed $seed, group $group',
          );
        }
      }
    });

    test('exclusion holds together with recent-mock avoidance', () {
      var recent = <List<String>>[];
      for (var seed = 0; seed < 300; seed++) {
        final chosen = ids(generate(seed, recent: recent));
        for (final group in groups) {
          expect(chosen.toSet().intersection(group).length, lessThan(2));
        }
        recent = [chosen, ...recent.take(1)];
      }
    });

    test('exclusion groups spanning temas are honoured too', () {
      final small = bankOf({1: 5, 2: 5});
      final config = MockConfig(size: 4, passMark: 3);
      final group = {'t1-001', 't2-001'};
      for (var seed = 0; seed < 200; seed++) {
        final mock = generate(
          seed,
          questions: small,
          config: config,
          exclusion: [group],
        );
        expect(ids(mock).toSet().intersection(group).length, lessThan(2));
      }
    });

    test('last resort: exclusion is relaxed only when there is no way out', () {
      // The whole bank is the mock, so both members of the group must appear.
      final tiny = bankOf({1: 3});
      final config = MockConfig(size: 3, passMark: 2);
      final mock = generate(
        1,
        questions: tiny,
        config: config,
        exclusion: [
          {'t1-001', 't1-002'},
        ],
      );
      expect(ids(mock).toSet(), {'t1-001', 't1-002', 't1-003'});
    });

    test('a bank smaller than the mock size is an error', () {
      expect(
        () => generate(1, questions: bankOf({1: 5, 2: 5})),
        throwsArgumentError,
      );
    });

    test('a bank of exactly the mock size returns all of it', () {
      final exact = bankOf({1: 12, 2: 8});
      final mock = generate(1, questions: exact, exclusion: const []);
      expect(ids(mock).toSet(), ids(exact).toSet());
    });
  });

  group('scoreMock', () {
    final config = MockConfig();
    // 20 questions: tema 1 x 10, tema 2 x 10, official answer always 1.
    final questions = [
      for (var i = 0; i < 20; i++) q(i < 10 ? 1 : 2, i, answer: 1),
    ];

    /// Answers with the first [right] correct and the rest wrong (or blank).
    List<int?> answers(int right, {bool blankRest = false}) => [
      for (var i = 0; i < 20; i++) i < right ? 1 : (blankRest ? null : 0),
    ];

    test('16 right answers is APTO', () {
      final r = scoreMock(
        questions: questions,
        answers: answers(16),
        config: config,
      );
      expect(r.correct, 16);
      expect(r.wrong, 4);
      expect(r.passed, isTrue);
    });

    test('15 right answers is NOT APTO', () {
      final r = scoreMock(
        questions: questions,
        answers: answers(15),
        config: config,
      );
      expect(r.correct, 15);
      expect(r.passed, isFalse);
    });

    test('20 and 0 right answers', () {
      final all = scoreMock(
        questions: questions,
        answers: answers(20),
        config: config,
      );
      expect(all.passed, isTrue);
      expect(all.wrong, 0);
      final none = scoreMock(
        questions: questions,
        answers: answers(0),
        config: config,
      );
      expect(none.passed, isFalse);
      expect(none.correct, 0);
    });

    test('unanswered counts as wrong', () {
      final r = scoreMock(
        questions: questions,
        answers: answers(15, blankRest: true),
        config: config,
      );
      expect(r.correct, 15);
      expect(r.unanswered, 5);
      expect(r.wrong, 5, reason: 'blanks are failures');
      expect(r.answeredWrong, 0);
      expect(r.total, 20);
      expect(r.passed, isFalse);
    });

    test('blank and wrong are told apart', () {
      final mixed = answers(10)
        ..[10] = null
        ..[11] = null;
      final r = scoreMock(questions: questions, answers: mixed, config: config);
      expect(r.correct, 10);
      expect(r.unanswered, 2);
      expect(r.wrong, 10);
      expect(r.answeredWrong, 8);
    });

    test('an all-blank mock scores 0', () {
      final r = scoreMock(
        questions: questions,
        answers: List<int?>.filled(20, null),
        config: config,
      );
      expect(r.correct, 0);
      expect(r.unanswered, 20);
      expect(r.passed, isFalse);
    });

    test('uses the configured pass mark', () {
      final strict = MockConfig(passMark: 18);
      expect(
        scoreMock(
          questions: questions,
          answers: answers(17),
          config: strict,
        ).passed,
        isFalse,
      );
      expect(
        scoreMock(
          questions: questions,
          answers: answers(18),
          config: strict,
        ).passed,
        isTrue,
      );
    });

    test('perTema has correct and total for each tema', () {
      // first 7 right: all in tema 1 (indexes 0..9), none in tema 2.
      final r = scoreMock(
        questions: questions,
        answers: answers(7),
        config: config,
      );
      expect(r.perTema, {
        1: (correct: 7, total: 10),
        2: (correct: 0, total: 10),
      });
      final r2 = scoreMock(
        questions: questions,
        answers: answers(13),
        config: config,
      );
      expect(r2.perTema, {
        1: (correct: 10, total: 10),
        2: (correct: 3, total: 10),
      });
    });

    test('perTema works on a generated mock (3/3/3/4/3/3/1 totals)', () {
      final bank = loadBank();
      final mock = generateMock(
        questions: bank,
        config: config,
        rng: Random(9),
      );
      final r = scoreMock(
        questions: mock,
        answers: [for (final x in mock) x.answer],
        config: config,
      );
      expect(r.passed, isTrue);
      expect(r.correct, 20);
      expect(
        {for (final e in r.perTema.entries) e.key: e.value.total},
        {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1},
      );
      expect(r.perTema.values.every((s) => s.correct == s.total), isTrue);
    });

    test('mismatched lengths are an error', () {
      expect(
        () =>
            scoreMock(questions: questions, answers: const [1], config: config),
        throwsArgumentError,
      );
    });

    test('results are comparable by value', () {
      final a = scoreMock(
        questions: questions,
        answers: answers(16),
        config: config,
      );
      final b = scoreMock(
        questions: questions,
        answers: answers(16),
        config: config,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          scoreMock(questions: questions, answers: answers(15), config: config),
        ),
      );
    });
  });
}
