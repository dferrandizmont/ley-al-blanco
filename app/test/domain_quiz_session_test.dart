import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/quiz_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Question `qN` whose official answer is option `answer` (0-based).
Question q(int n, {int answer = 0}) => Question(
  id: 'q$n',
  tema: 1,
  stem: 'Stem $n',
  options: const ['A', 'B', 'C'],
  answer: answer,
  edition: 'test',
);

final now = DateTime.utc(2026, 10, 19, 12);

QuizSession session(AttemptMode mode, {int count = 3}) =>
    QuizSession(questions: [for (var i = 0; i < count; i++) q(i)], mode: mode);

void main() {
  group('immediate feedback (practice)', () {
    test('starts at the first question, nothing answered', () {
      final s = session(AttemptMode.practice);
      expect(s.currentIndex, 0);
      expect(s.answeredCount, 0);
      expect(s.isFinished, isFalse);
      expect(s.hasImmediateFeedback, isTrue);
      expect(s.feedbackFor(0), isNull);
    });

    test('select gives immediate feedback with the correct index', () {
      final s = session(AttemptMode.practice).select(2);
      expect(s.isAnswered(0), isTrue);
      expect(
        s.feedbackFor(0),
        const AnswerFeedback(selected: 2, correctIndex: 0),
      );
      expect(s.feedbackFor(0)!.isCorrect, isFalse);
      expect(s.select(0).correctCount, 0, reason: 'second answer ignored');
    });

    test('a right answer is flagged correct', () {
      final s = session(AttemptMode.practice).select(0);
      expect(s.feedbackFor(0)!.isCorrect, isTrue);
      expect(s.correctCount, 1);
    });

    test('answering twice is a no-op that keeps the first answer', () {
      final once = session(AttemptMode.practice).select(1);
      final twice = once.select(0);
      expect(twice, same(once));
      expect(twice.answers[0], 1);
    });

    test('next is blocked until the current question is answered', () {
      final s = session(AttemptMode.practice);
      expect(s.next().currentIndex, 0);
      expect(s.select(0).next().currentIndex, 1);
    });

    test('goTo cannot skip past the first unanswered question', () {
      final s = session(AttemptMode.practice, count: 4).select(0).next();
      expect(s.goTo(3).currentIndex, 1, reason: 'q1 is still unanswered');
      expect(s.goTo(1).currentIndex, 1);
      expect(s.goTo(0).currentIndex, 0);
    });

    test('previous goes back, no-op on the first', () {
      final s = session(AttemptMode.practice).select(0).next();
      expect(s.previous().currentIndex, 0);
      expect(s.previous().previous().currentIndex, 0);
    });

    test(
      'previous keeps the answers and the feedback of earlier questions',
      () {
        final s = session(AttemptMode.practice).select(2).next().previous();
        expect(s.feedbackFor(0)!.selected, 2);
      },
    );

    test('next is a no-op on the last question', () {
      final s = session(AttemptMode.practice, count: 1).select(0);
      expect(s.isLastQuestion, isTrue);
      expect(s.next(), same(s));
    });

    test('is finished when every question is answered', () {
      var s = session(AttemptMode.practice, count: 2).select(0);
      expect(s.isFinished, isFalse);
      s = s.next().select(1);
      expect(s.isFinished, isTrue);
      expect(s.answeredCount, 2);
      expect(s.correctCount, 1);
    });

    test('submit is not available', () {
      expect(() => session(AttemptMode.practice).submit(), throwsStateError);
    });

    test('review and srs behave like practice', () {
      for (final mode in [AttemptMode.review, AttemptMode.srs]) {
        final s = session(mode).select(1);
        expect(s.feedbackFor(0), isNotNull, reason: mode.name);
        expect(s.select(0).answers[0], 1, reason: mode.name);
      }
    });

    test('selecting an option that does not exist is a RangeError', () {
      expect(() => session(AttemptMode.practice).select(3), throwsRangeError);
      expect(() => session(AttemptMode.practice).select(-1), throwsRangeError);
    });

    test('toAttempts returns only answered questions', () {
      final s = session(AttemptMode.practice).select(0).next().select(2);
      final attempts = s.toAttempts(now: now);
      expect(attempts, [
        Attempt(
          questionId: 'q0',
          mode: AttemptMode.practice,
          selected: 0,
          correct: true,
          answeredAt: now,
        ),
        Attempt(
          questionId: 'q1',
          mode: AttemptMode.practice,
          selected: 2,
          correct: false,
          answeredAt: now,
        ),
      ]);
    });

    test('toAttempts works mid-session and carries the mode', () {
      final attempts = session(AttemptMode.srs)
          .select(0)
          .toAttempts(now: now, mockId: null);
      expect(attempts.single.mode, AttemptMode.srs);
    });
  });

  group('mock', () {
    test('no feedback before submit, even after answering', () {
      final s = session(AttemptMode.mock).select(1);
      expect(s.hasImmediateFeedback, isFalse);
      expect(s.feedbackFor(0), isNull);
      expect(s.isFinished, isFalse);
    });

    test('the answer can be changed until submit', () {
      final s = session(AttemptMode.mock).select(1).select(0).select(2);
      expect(s.answers[0], 2);
      expect(s.answeredCount, 1);
    });

    test('next and goTo move freely without answering', () {
      final s = session(AttemptMode.mock, count: 5);
      expect(s.next().next().currentIndex, 2);
      expect(s.goTo(4).currentIndex, 4);
      expect(s.goTo(4).goTo(1).currentIndex, 1);
    });

    test('goTo out of range is a RangeError', () {
      expect(() => session(AttemptMode.mock).goTo(3), throwsRangeError);
      expect(() => session(AttemptMode.mock).goTo(-1), throwsRangeError);
    });

    test('answers survive navigation', () {
      final s = session(AttemptMode.mock).select(1).next().select(2).goTo(0);
      expect(s.answers, [1, 2, null]);
    });

    test('submit unlocks feedback, including for blank questions', () {
      final s = session(AttemptMode.mock).select(0).next().select(2).submit();
      expect(s.submitted, isTrue);
      expect(s.isFinished, isTrue);
      expect(s.feedbackFor(0)!.isCorrect, isTrue);
      expect(s.feedbackFor(1)!.isCorrect, isFalse);
      expect(
        s.feedbackFor(2),
        const AnswerFeedback(selected: null, correctIndex: 0),
      );
      expect(s.feedbackFor(2)!.isCorrect, isFalse);
    });

    test('after submit the session is read-only', () {
      final s = session(AttemptMode.mock).select(0).submit();
      expect(s.select(1), same(s));
      expect(s.answers[0], 0);
      expect(s.submit(), same(s), reason: 'submitting twice is a no-op');
    });

    test('toAttempts needs submit', () {
      expect(
        () => session(AttemptMode.mock).toAttempts(now: now),
        throwsStateError,
      );
    });

    test('toAttempts has one attempt per question, blanks as wrong', () {
      final s = session(AttemptMode.mock).select(0).next().select(1).submit();
      final attempts = s.toAttempts(now: now, mockId: 7);
      expect(attempts, hasLength(3));
      expect(attempts.map((a) => a.questionId), ['q0', 'q1', 'q2']);
      expect(attempts.map((a) => a.selected), [0, 1, null]);
      expect(attempts.map((a) => a.correct), [true, false, false]);
      expect(attempts.every((a) => a.mode == AttemptMode.mock), isTrue);
      expect(attempts.every((a) => a.mockId == 7), isTrue);
      expect(attempts.every((a) => a.answeredAt == now), isTrue);
    });
  });

  group('value semantics', () {
    test('sessions are immutable: transitions return new instances', () {
      final a = session(AttemptMode.mock);
      final b = a.select(1);
      expect(a.answers, [null, null, null]);
      expect(b.answers, [1, null, null]);
      expect(() => b.answers[0] = 2, throwsUnsupportedError);
      expect(() => b.questions.clear(), throwsUnsupportedError);
    });

    test('equal sessions are == and share hashCode', () {
      final a = session(AttemptMode.mock).select(1).next();
      final b = session(AttemptMode.mock).select(1).next();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.select(2)));
    });

    test('rejects invalid construction', () {
      expect(
        () => QuizSession(questions: const [], mode: AttemptMode.practice),
        throwsArgumentError,
      );
      expect(
        () => QuizSession(
          questions: [q(0)],
          mode: AttemptMode.practice,
          answers: const [null, null],
        ),
        throwsArgumentError,
      );
      expect(
        () => QuizSession(
          questions: [q(0)],
          mode: AttemptMode.practice,
          submitted: true,
        ),
        throwsArgumentError,
      );
    });

    test('options are never reordered', () {
      final s = session(AttemptMode.practice);
      expect(s.currentQuestion.options, ['A', 'B', 'C']);
      expect(s.select(2).currentQuestion.options, ['A', 'B', 'C']);
    });
  });
}
