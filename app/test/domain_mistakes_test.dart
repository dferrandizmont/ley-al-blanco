import 'package:apto_armas/features/mistakes/domain/mistakes.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

final day0 = DateTime.utc(2026, 10, 1, 10);
DateTime at(int days, [int hours = 0]) =>
    day0.add(Duration(days: days, hours: hours));

Attempt attempt(
  String id,
  bool correct,
  DateTime when, {
  AttemptMode mode = AttemptMode.practice,
}) => Attempt(
  questionId: id,
  mode: mode,
  selected: correct ? 0 : 1,
  correct: correct,
  answeredAt: when,
);

List<String> idsOf(List<MistakeEntry> entries) => [
  for (final e in entries) e.questionId,
];

void main() {
  test('no attempts, no mistakes', () {
    expect(mistakes(const []), isEmpty);
  });

  test('a question only ever answered right never enters', () {
    expect(
      mistakes([attempt('q1', true, at(0)), attempt('q1', true, at(1))]),
      isEmpty,
    );
  });

  test('a wrong answer in a mock enters the list', () {
    final result = mistakes([
      attempt('q1', false, at(0), mode: AttemptMode.mock),
    ]);
    expect(result, [
      MistakeEntry(
        questionId: 'q1',
        lastWrongAt: at(0),
        wrongCount: 1,
        currentStreak: 0,
      ),
    ]);
  });

  test('a blank mock question (selected null, correct false) is a mistake', () {
    final blank = Attempt(
      questionId: 'q1',
      mode: AttemptMode.mock,
      selected: null,
      correct: false,
      answeredAt: at(0),
      mockId: 1,
    );
    expect(idsOf(mistakes([blank])), ['q1']);
  });

  test('one correct answer afterwards keeps it', () {
    final result = mistakes([
      attempt('q1', false, at(0)),
      attempt('q1', true, at(1)),
    ]);
    expect(idsOf(result), ['q1']);
    expect(result.single.currentStreak, 1);
  });

  test('two consecutive correct answers remove it', () {
    expect(
      mistakes([
        attempt('q1', false, at(0)),
        attempt('q1', true, at(1)),
        attempt('q1', true, at(2)),
      ]),
      isEmpty,
    );
  });

  test('correct answers in any mode count towards the streak', () {
    expect(
      mistakes([
        attempt('q1', false, at(0), mode: AttemptMode.mock),
        attempt('q1', true, at(1), mode: AttemptMode.srs),
        attempt('q1', true, at(2), mode: AttemptMode.review),
      ]),
      isEmpty,
    );
  });

  test('a wrong answer in between resets the streak', () {
    final result = mistakes([
      attempt('q1', false, at(0)),
      attempt('q1', true, at(1)),
      attempt('q1', false, at(2)),
      attempt('q1', true, at(3)),
    ]);
    expect(idsOf(result), ['q1']);
    expect(result.single.currentStreak, 1);
    expect(result.single.wrongCount, 2);
    expect(result.single.lastWrongAt, at(2));
  });

  test('a wrong answer after leaving the list re-adds the question', () {
    final result = mistakes([
      attempt('q1', false, at(0)),
      attempt('q1', true, at(1)),
      attempt('q1', true, at(2)),
      attempt('q1', false, at(3)),
    ]);
    expect(idsOf(result), ['q1']);
    expect(result.single.wrongCount, 2);
    expect(result.single.currentStreak, 0);
  });

  test('attempts given out of order are sorted by answeredAt', () {
    // Chronologically: wrong, right, right -> out of the list.
    final shuffled = [
      attempt('q1', true, at(2)),
      attempt('q1', false, at(0)),
      attempt('q1', true, at(1)),
    ];
    expect(mistakes(shuffled), isEmpty);
    // Chronologically: right, right, wrong -> in the list.
    final other = [
      attempt('q1', false, at(2)),
      attempt('q1', true, at(0)),
      attempt('q1', true, at(1)),
    ];
    expect(idsOf(mistakes(other)), ['q1']);
  });

  test('equal timestamps keep the input order', () {
    final result = mistakes([
      attempt('q1', false, at(0)),
      attempt('q1', true, at(0)),
    ]);
    expect(result.single.currentStreak, 1);
  });

  test('requiredStreak is configurable', () {
    final history = [
      attempt('q1', false, at(0)),
      attempt('q1', true, at(1)),
      attempt('q1', true, at(2)),
    ];
    expect(mistakes(history), isEmpty);
    expect(idsOf(mistakes(history, requiredStreak: 3)), ['q1']);
    expect(
      mistakes([
        attempt('q1', false, at(0)),
        attempt('q1', true, at(1)),
      ], requiredStreak: 1),
      isEmpty,
    );
  });

  test('requiredStreak below 1 is an error', () {
    expect(() => mistakes(const [], requiredStreak: 0), throwsArgumentError);
  });

  test('sorted by lastWrongAt, newest first', () {
    final result = mistakes([
      attempt('a', false, at(1)),
      attempt('b', false, at(3)),
      attempt('c', false, at(2)),
    ]);
    expect(idsOf(result), ['b', 'c', 'a']);
  });

  test('questions are independent of each other', () {
    final result = mistakes([
      attempt('a', false, at(0)),
      attempt('b', true, at(0)),
      attempt('a', true, at(1)),
      attempt('a', true, at(2)),
      attempt('c', false, at(2)),
    ]);
    expect(idsOf(result), ['c']);
  });

  group('tema filter', () {
    final temaById = {'a': 1, 'b': 2, 'c': 2};
    final history = [
      attempt('a', false, at(1)),
      attempt('b', false, at(2)),
      attempt('c', false, at(3)),
      attempt('zz', false, at(4)),
    ];

    test('keeps only the questions of that tema', () {
      expect(idsOf(mistakes(history, temaById: temaById, tema: 2)), ['c', 'b']);
      expect(idsOf(mistakes(history, temaById: temaById, tema: 1)), ['a']);
    });

    test('questions unknown to temaById are left out of a filtered list', () {
      expect(mistakes(history, temaById: temaById, tema: 3), isEmpty);
    });

    test('without tema, temaById is not needed and nothing is filtered', () {
      expect(mistakes(history), hasLength(4));
      expect(mistakes(history, temaById: temaById), hasLength(4));
    });

    test('tema without temaById is an error', () {
      expect(() => mistakes(history, tema: 1), throwsArgumentError);
    });
  });
}
