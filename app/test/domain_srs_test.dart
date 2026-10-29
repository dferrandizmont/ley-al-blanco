import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/srs/domain/daily_queue.dart';
import 'package:apto_armas/features/srs/domain/srs_card.dart';
import 'package:apto_armas/features/srs/domain/srs_review.dart';
import 'package:flutter_test/flutter_test.dart';

// Everything here uses LOCAL DateTimes and asserts calendar fields, so the
// tests pass in any machine time zone (CI runs with TZ=Europe/Madrid, where
// 2026-10-25 lasts 25 h and 2027-03-28 lasts 23 h).

/// Asserts that [actual] is local midnight of the given calendar day.
void expectMidnight(DateTime actual, int year, int month, int day) {
  expect(
    [
      actual.year,
      actual.month,
      actual.day,
      actual.hour,
      actual.minute,
      actual.second,
      actual.millisecond,
    ],
    [year, month, day, 0, 0, 0, 0],
    reason: 'got $actual',
  );
}

SrsCard card(
  String id, {
  int box = 1,
  required DateTime dueAt,
  int reps = 1,
  int lapses = 0,
  DateTime? lastAnsweredAt,
}) => SrsCard(
  questionId: id,
  box: box,
  dueAt: dueAt,
  reps: reps,
  lapses: lapses,
  lastAnsweredAt: lastAnsweredAt ?? DateTime(2026, 10, 1),
);

Question q(String id, int tema) => Question(
  id: id,
  tema: tema,
  stem: 'Stem $id',
  options: const ['A', 'B', 'C'],
  answer: 0,
  edition: 'test',
);

void main() {
  group('review: box transitions', () {
    final now = DateTime(2026, 10, 19, 18, 30);

    test('intervals are 0/1/3/7/16 days', () {
      expect(kLeitnerIntervalsDays, [0, 1, 3, 7, 16]);
    });

    test('new card answered right goes to box 2', () {
      final c = review(null, questionId: 'q', correct: true, now: now);
      expect(c.box, 2);
      expect(c.reps, 1);
      expect(c.lapses, 0);
      expect(c.questionId, 'q');
      expect(c.lastAnsweredAt, now);
      expectMidnight(c.dueAt, 2026, 10, 20);
    });

    test('new card answered wrong goes to box 1, due today, no lapse', () {
      final c = review(null, questionId: 'q', correct: false, now: now);
      expect(c.box, 1);
      expect(c.lapses, 0);
      expect(c.reps, 1);
      expectMidnight(c.dueAt, 2026, 10, 19);
    });

    test('each right answer climbs one box up to 5', () {
      SrsCard? c;
      final boxes = <int>[];
      for (var i = 0; i < 6; i++) {
        c = review(c, questionId: 'q', correct: true, now: now);
        boxes.add(c.box);
      }
      expect(boxes, [2, 3, 4, 5, 5, 5]);
      expect(c!.reps, 6);
      expect(c.lapses, 0);
    });

    test('due date follows the box interval', () {
      final dues = <int, DateTime>{};
      SrsCard? c;
      for (var i = 0; i < 4; i++) {
        c = review(c, questionId: 'q', correct: true, now: now);
        dues[c.box] = c.dueAt;
      }
      expectMidnight(dues[2]!, 2026, 10, 20);
      expectMidnight(dues[3]!, 2026, 10, 22);
      expectMidnight(dues[4]!, 2026, 10, 26);
      expectMidnight(dues[5]!, 2026, 11, 4);
    });

    test('a wrong answer drops to box 1 and counts a lapse', () {
      var c = review(null, questionId: 'q', correct: true, now: now);
      c = review(c, questionId: 'q', correct: true, now: now);
      c = review(c, questionId: 'q', correct: true, now: now);
      expect(c.box, 4);
      final wrong = review(c, questionId: 'q', correct: false, now: now);
      expect(wrong.box, 1);
      expect(wrong.lapses, 1);
      expect(wrong.reps, 4);
      expectMidnight(wrong.dueAt, 2026, 10, 19);
      final again = review(wrong, questionId: 'q', correct: false, now: now);
      expect(again.lapses, 2);
    });

    test('review is pure: the input card is not modified', () {
      final c = review(null, questionId: 'q', correct: true, now: now);
      review(c, questionId: 'q', correct: true, now: now);
      expect(c.box, 2);
      expect(c.reps, 1);
    });

    test('a card of another question is rejected', () {
      final c = review(null, questionId: 'a', correct: true, now: now);
      expect(
        () => review(c, questionId: 'b', correct: true, now: now),
        throwsArgumentError,
      );
    });

    test('equal cards are == with the same hashCode', () {
      final a = review(null, questionId: 'q', correct: true, now: now);
      final b = review(null, questionId: 'q', correct: true, now: now);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('review: dates with calendar arithmetic', () {
    test('due date is the start of the local day, whatever the hour', () {
      for (final hour in [0, 7, 23]) {
        final c = review(
          null,
          questionId: 'q',
          correct: true,
          now: DateTime(2026, 5, 10, hour, 59),
        );
        expectMidnight(c.dueAt, 2026, 5, 11);
      }
    });

    test(
      'autumn clock change (2026-10-25): +1 day is midnight on the 25th',
      () {
        final c = review(
          null,
          questionId: 'q',
          correct: true,
          now: DateTime(2026, 10, 24, 22, 30),
        );
        expectMidnight(c.dueAt, 2026, 10, 25);
      },
    );

    test('autumn clock change: +3 days across the 25 h day lands on 00:00', () {
      var c = review(
        null,
        questionId: 'q',
        correct: true,
        now: DateTime(2026, 10, 24, 22, 30),
      );
      c = review(
        c,
        questionId: 'q',
        correct: true,
        now: DateTime(2026, 10, 24, 22, 30),
      );
      expect(c.box, 3);
      // A 72 h Duration would be 2026-10-26 23:00 in Madrid.
      expectMidnight(c.dueAt, 2026, 10, 27);
    });

    test('autumn clock change: box 5 (+16 days) from before the change', () {
      var c = review(
        null,
        questionId: 'q',
        correct: true,
        now: DateTime(2026, 10, 20, 9),
      );
      for (var i = 0; i < 3; i++) {
        c = review(
          c,
          questionId: 'q',
          correct: true,
          now: DateTime(2026, 10, 20, 9),
        );
      }
      expect(c.box, 5);
      expectMidnight(c.dueAt, 2026, 11, 5);
    });

    test('spring clock change (2027-03-28): +3 days across the 23 h day', () {
      var c = review(
        null,
        questionId: 'q',
        correct: true,
        now: DateTime(2027, 3, 26, 23, 59),
      );
      c = review(
        c,
        questionId: 'q',
        correct: true,
        now: DateTime(2027, 3, 26, 23, 59),
      );
      expect(c.box, 3);
      // A 72 h Duration would be 2027-03-29 01:00 in Madrid.
      expectMidnight(c.dueAt, 2027, 3, 29);
    });

    test('spring clock change: +1 day from the day before', () {
      final c = review(
        null,
        questionId: 'q',
        correct: true,
        now: DateTime(2027, 3, 27, 12),
      );
      expectMidnight(c.dueAt, 2027, 3, 28);
    });

    test('spring clock change: answering during the 23 h day itself', () {
      final c = review(
        null,
        questionId: 'q',
        correct: true,
        now: DateTime(2027, 3, 28, 12),
      );
      expectMidnight(c.dueAt, 2027, 3, 29);
    });

    test('month and year rollover', () {
      var c = review(
        null,
        questionId: 'q',
        correct: true,
        now: DateTime(2026, 12, 31, 20),
      );
      expectMidnight(c.dueAt, 2027, 1, 1);
      for (var i = 0; i < 3; i++) {
        c = review(
          c,
          questionId: 'q',
          correct: true,
          now: DateTime(2026, 12, 31, 20),
        );
      }
      expect(c.box, 5);
      expectMidnight(c.dueAt, 2027, 1, 16);
    });

    test('a UTC instant is read in local time', () {
      final utc = DateTime.utc(2026, 10, 19, 12);
      final c = review(null, questionId: 'q', correct: true, now: utc);
      final local = utc.toLocal();
      expect(c.dueAt.isUtc, isFalse);
      expectMidnight(c.dueAt, local.year, local.month, local.day + 1);
    });

    test('startOfLocalDay', () {
      expectMidnight(
        startOfLocalDay(DateTime(2026, 10, 25, 23, 59)),
        2026,
        10,
        25,
      );
      expectMidnight(
        startOfLocalDay(DateTime(2026, 10, 25, 23, 59), plusDays: 1),
        2026,
        10,
        26,
      );
    });
  });

  group('dailyQueue', () {
    final now = DateTime(2026, 10, 19, 15);
    final today = DateTime(2026, 10, 19);
    final yesterday = DateTime(2026, 10, 18);
    final tomorrow = DateTime(2026, 10, 20);
    final questions = [
      for (var t = 1; t <= 3; t++)
        for (var n = 1; n <= 4; n++) q('t$t-$n', t),
    ];

    List<String> queue({
      Iterable<SrsCard> cards = const [],
      List<Question>? qs,
      Map<int, double> mastery = const {1: 0.5, 2: 0.5, 3: 0.5},
      int newPerDay = 15,
      int introduced = 0,
    }) => dailyQueue(
      cards: cards,
      questions: qs ?? questions,
      now: now,
      masteryByTema: mastery,
      newPerDay: newPerDay,
      newIntroducedToday: introduced,
    );

    test('due cards: overdue and today are in, tomorrow is out', () {
      final result = queue(
        cards: [
          card('t1-1', dueAt: yesterday),
          card('t1-2', dueAt: today),
          card('t1-3', dueAt: tomorrow),
        ],
        newPerDay: 0,
      );
      expect(result, ['t1-1', 't1-2']);
    });

    test('end of today is inclusive, start of tomorrow is not', () {
      final result = queue(
        cards: [
          card('t1-1', dueAt: tomorrow.subtract(const Duration(minutes: 1))),
          card('t1-2', dueAt: tomorrow),
        ],
        newPerDay: 0,
      );
      expect(result, ['t1-1']);
    });

    test('due cards are ordered by dueAt, then box, then id', () {
      final result = queue(
        cards: [
          card('t2-1', box: 3, dueAt: today),
          card('t1-4', box: 1, dueAt: today),
          card('t1-2', box: 1, dueAt: today),
          card('t3-1', box: 5, dueAt: yesterday),
          card('t1-1', box: 2, dueAt: DateTime(2026, 10, 17)),
        ],
        newPerDay: 0,
      );
      expect(result, ['t1-1', 't3-1', 't1-2', 't1-4', 't2-1']);
    });

    test('due cards come before new questions', () {
      final result = queue(
        cards: [card('t3-4', dueAt: today)],
        newPerDay: 2,
        mastery: {1: 0.1, 2: 0.5, 3: 0.9},
      );
      expect(result, ['t3-4', 't1-1', 't1-2']);
    });

    test('recent answers move to the end without changing selection', () {
      final cards = [
        card('t1-1', dueAt: yesterday, lastAnsweredAt: now),
        card(
          't1-2',
          dueAt: today,
          lastAnsweredAt: now.subtract(const Duration(minutes: 9, seconds: 59)),
        ),
        card(
          't1-3',
          dueAt: today,
          lastAnsweredAt: now.subtract(const Duration(minutes: 10)),
        ),
        card('t1-4', dueAt: tomorrow, lastAnsweredAt: now),
      ];
      expect(queue(cards: cards, newPerDay: 2), [
        't1-3',
        't2-1',
        't2-2',
        't1-1',
        't1-2',
      ]);
      expect(queue(cards: cards, introduced: 15), ['t1-3', 't1-1', 't1-2']);
      expect(
        queue(cards: cards.reversed, newPerDay: 2),
        queue(cards: cards, newPerDay: 2),
      );
    });

    test('a just failed question returns to due order after ten minutes', () {
      final failed = review(null, questionId: 't1-1', correct: false, now: now);
      final cards = [failed, card('t1-2', dueAt: today)];
      expect(queue(cards: cards, newPerDay: 1), ['t1-2', 't1-3', 't1-1']);
      expect(
        dailyQueue(
          cards: cards,
          questions: questions,
          now: now.add(const Duration(minutes: 10)),
          masteryByTema: const {},
          newPerDay: 1,
        ),
        ['t1-1', 't1-2', 't1-3'],
      );
      expect(failed.box, 1);
      expect(failed.dueAt, today);
    });

    test('cards for retired questions are ignored', () {
      final result = queue(
        cards: [
          card('gone-1', dueAt: yesterday),
          card('t1-1', dueAt: today),
        ],
        newPerDay: 0,
      );
      expect(result, ['t1-1']);
    });

    test('new questions are capped at newPerDay (default 15)', () {
      final many = [for (var n = 1; n <= 40; n++) q('t1-$n', 1)];
      expect(queue(qs: many), hasLength(15));
      expect(queue(qs: many, newPerDay: 5), hasLength(5));
    });

    test('questions already introduced today reduce the quota', () {
      final many = [for (var n = 1; n <= 40; n++) q('t1-$n', 1)];
      expect(queue(qs: many, introduced: 10), hasLength(5));
      expect(queue(qs: many, introduced: 15), isEmpty);
      expect(
        queue(qs: many, introduced: 99),
        isEmpty,
        reason: 'never negative',
      );
    });

    test('the quota only limits new questions, never due ones', () {
      final result = queue(
        cards: [
          card('t1-1', dueAt: today),
          card('t1-2', dueAt: today),
          card('t1-3', dueAt: today),
        ],
        introduced: 15,
      );
      expect(result, ['t1-1', 't1-2', 't1-3']);
    });

    test('questions with a card, due later, are not offered as new', () {
      final result = queue(
        cards: [card('t1-1', dueAt: tomorrow)],
        qs: [q('t1-1', 1), q('t1-2', 1)],
      );
      expect(result, ['t1-2']);
    });

    test('new questions favour the tema with the least mastery', () {
      final result = queue(newPerDay: 6, mastery: {1: 0.8, 2: 0.2, 3: 0.5});
      expect(result, ['t2-1', 't2-2', 't2-3', 't2-4', 't3-1', 't3-2']);
    });

    test('mastery ties are broken by tema, then by question order', () {
      final shuffled = [q('t2-b', 2), q('t1-b', 1), q('t1-a', 1)];
      final result = queue(qs: shuffled, mastery: {1: 0.5, 2: 0.5});
      expect(result, ['t1-b', 't1-a', 't2-b']);
    });

    test('a tema missing from the mastery map counts as unknown (first)', () {
      final result = queue(newPerDay: 1, mastery: {1: 0.9, 2: 0.9});
      expect(result, ['t3-1']);
    });

    test('empty everything gives an empty queue', () {
      expect(queue(qs: const []), isEmpty);
    });

    test('is deterministic', () {
      final cards = [card('t2-2', dueAt: today), card('t1-2', dueAt: today)];
      expect(queue(cards: cards), queue(cards: cards.reversed));
    });
  });
}
