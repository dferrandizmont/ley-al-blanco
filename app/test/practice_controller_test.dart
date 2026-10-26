import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mistakes/application/mistakes_providers.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:apto_armas/features/quiz/domain/quiz_session.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/study_support.dart';

/// Builds the controller for [source] and keeps it alive for the test.
Future<PracticeState> start(ProviderContainer c, PracticeSource source) {
  c.listen(practiceControllerProvider(source), (previous, next) {});
  return c.read(practiceControllerProvider(source).future);
}

PracticeController controller(ProviderContainer c, PracticeSource source) =>
    c.read(practiceControllerProvider(source).notifier);

PracticeState current(ProviderContainer c, PracticeSource source) =>
    c.read(practiceControllerProvider(source)).requireValue;

void main() {
  group('the duration of an answer', () {
    const source = TemaPractice(3);

    Future<int?> elapsedAfter(Duration shift) async {
      var now = kStudyNow;
      final c = makeStudyContainer(clock: () => now);
      final session = (await start(c, source)).session!;
      now = kStudyNow.add(shift);
      await controller(c, source).answer(session.currentQuestion.answer);
      return (await c.read(attemptRepositoryProvider).all()).single.elapsedMs;
    }

    test('is the time the question was on screen', () async {
      expect(await elapsedAfter(const Duration(seconds: 7)), 7000);
    });

    test('never negative if the clock went back', () async {
      expect(await elapsedAfter(const Duration(hours: -3)), 0);
    });

    test('never more than a day if the clock jumped forward', () async {
      expect(
        await elapsedAfter(const Duration(days: 40)),
        kMaxAttemptElapsedMs,
      );
    });
  });

  group('tema source', () {
    const source = TemaPractice(3);

    test('bank order of the tema, from the start on a fresh install', () async {
      final c = makeStudyContainer();
      final state = await start(c, source);
      final bank = await c.read(questionsProvider.future);
      final session = state.session!;
      expect(session.mode, AttemptMode.practice);
      expect(session.questions, bank.where((q) => q.tema == 3).toList());
      expect(session.currentIndex, 0);
      expect(state.finished, isFalse);
      expect(state.saving, isFalse);
    });

    test('starts at the first never-answered question', () async {
      final c = makeStudyContainer();
      final bank = await c.read(questionsProvider.future);
      final tema3 = bank.where((q) => q.tema == 3).toList();
      await c.read(studyServiceProvider).recordAnswers([
        for (final q in tema3.take(4)) attemptOn(q, correct: true),
      ]);
      await settle();
      final session = (await start(c, source)).session!;
      expect(session.questions.first, tema3[4]);
      expect(session.length, tema3.length - 4);
    });

    test('a blank mock slot does not move the resume point', () async {
      final c = makeStudyContainer();
      final bank = await c.read(questionsProvider.future);
      final tema3 = bank.where((q) => q.tema == 3).toList();
      // 0 answered, 1 left blank in a mock (a miss with no pick), 2 answered.
      await c.read(studyServiceProvider).recordAnswers([
        attemptOn(tema3[0], correct: true),
        Attempt(
          questionId: tema3[1].id,
          mode: AttemptMode.mock,
          selected: null,
          correct: false,
          answeredAt: kStudyNow,
        ),
        attemptOn(tema3[2], correct: false),
      ]);
      await settle();
      final session = (await start(c, source)).session!;
      // Resumes at the never-answered question 1, not after question 2.
      expect(session.questions.first, tema3[1]);
      expect(session.length, tema3.length - 1);
    });

    test('only blank mock slots: the tema starts from the top', () async {
      final c = makeStudyContainer();
      final bank = await c.read(questionsProvider.future);
      final tema3 = bank.where((q) => q.tema == 3).toList();
      await c.read(studyServiceProvider).recordAnswers([
        for (final q in tema3.take(3))
          Attempt(
            questionId: q.id,
            mode: AttemptMode.mock,
            selected: null,
            correct: false,
            answeredAt: kStudyNow,
          ),
      ]);
      await settle();
      final session = (await start(c, source)).session!;
      expect(session.questions, tema3);
    });

    test(
      'answer(): locks, stores the attempt right away, ignores a retry',
      () async {
        final c = makeStudyContainer();
        final session = (await start(c, source)).session!;
        final q = session.currentQuestion;

        await controller(c, source).answer(wrongOption(q));

        final state = current(c, source);
        expect(state.saving, isFalse);
        expect(state.session!.answers.first, wrongOption(q));
        final attempts = await c.read(attemptRepositoryProvider).all();
        expect(attempts, hasLength(1));
        expect(attempts.single.questionId, q.id);
        expect(attempts.single.mode, AttemptMode.practice);
        expect(attempts.single.correct, isFalse);
        expect(attempts.single.answeredAt, kStudyNow);
        expect(attempts.single.elapsedMs, 0);
        expect(
          (await c.read(srsRepositoryProvider).get(q.id))!.box,
          1,
          reason: 'a miss puts the card in box 1',
        );

        // A second pick on the same question changes nothing.
        await controller(c, source).answer(q.answer);
        expect(current(c, source).session!.answers.first, wrongOption(q));
        await settle();
        expect(await c.read(attemptRepositoryProvider).all(), hasLength(1));
      },
    );

    test(
      'next() needs an answer; moves on; the last one ends the session',
      () async {
        final c = makeStudyContainer();
        final session = (await start(c, source)).session!;
        final ctrl = controller(c, source);

        ctrl.next(); // unanswered: no-op
        expect(current(c, source).session!.currentIndex, 0);

        for (var i = 0; i < session.length; i++) {
          final q = current(c, source).session!.currentQuestion;
          await ctrl.answer(q.answer);
          expect(current(c, source).finished, isFalse);
          ctrl.next();
        }
        final end = current(c, source);
        expect(end.finished, isTrue);
        expect(end.session!.correctCount, session.length);
        expect(
          await c.read(attemptRepositoryProvider).all(),
          hasLength(session.length),
        );
      },
    );

    test('a failing write takes the pick back and counts the error', () async {
      final c = makeStudyContainer(
        overrides: [
          srsRepositoryProvider.overrideWith(
            (ref) =>
                FailingSrsRepository(ref.watch(appDatabaseProvider), failOn: 1),
          ),
        ],
      );
      final q = (await start(c, source)).session!.currentQuestion;
      await controller(c, source).answer(q.answer);

      final state = current(c, source);
      expect(state.saveErrors, 1);
      expect(state.saving, isFalse);
      expect(
        state.session!.isAnswered(0),
        isFalse,
        reason: 'can be picked again',
      );
      expect(
        await c.read(attemptRepositoryProvider).all(),
        isEmpty,
        reason: 'atomic',
      );

      // The next try works (the failure was only the first call).
      await controller(c, source).answer(q.answer);
      expect(current(c, source).session!.isAnswered(0), isTrue);
      expect(current(c, source).saveErrors, 1);
    });
  });

  group('daily source', () {
    test('is the Continuar queue, in srs mode', () async {
      final c = makeStudyContainer();
      final queue = await c.read(dailyQueueProvider.future);
      final state = await start(c, const DailyPractice());
      expect(state.session!.mode, AttemptMode.srs);
      expect([for (final q in state.session!.questions) q.id], queue);
      expect(queue, hasLength(15));

      await controller(
        c,
        const DailyPractice(),
      ).answer(state.session!.currentQuestion.answer);
      final attempts = await c.read(attemptRepositoryProvider).all();
      expect(attempts.single.mode, AttemptMode.srs);
    });

    test(
      'the session is a snapshot: answering does not reshuffle it',
      () async {
        final c = makeStudyContainer();
        final state = await start(c, const DailyPractice());
        final ids = [for (final q in state.session!.questions) q.id];
        final ctrl = controller(c, const DailyPractice());
        await ctrl.answer(state.session!.currentQuestion.answer);
        ctrl.next();
        await settle();
        expect([
          for (final q in current(c, const DailyPractice()).session!.questions)
            q.id,
        ], ids);
      },
    );
  });

  group('mistakes source', () {
    test(
      'review mode over the failed questions, optionally of a tema',
      () async {
        final c = makeStudyContainer();
        final bank = await c.read(questionsProvider.future);
        final t2 = bank.firstWhere((q) => q.tema == 2);
        final t5 = bank.firstWhere((q) => q.tema == 5);
        await c.read(studyServiceProvider).recordAnswers([
          attemptOn(t2, correct: false, at: kStudyNow),
          attemptOn(
            t5,
            correct: false,
            at: kStudyNow.add(const Duration(minutes: 1)),
          ),
        ]);
        await settle();

        final all = await start(c, const MistakesPractice());
        expect(all.session!.mode, AttemptMode.review);
        expect(
          [for (final q in all.session!.questions) q.id],
          [t5.id, t2.id],
          reason: 'newest mistake first',
        );

        final onlyTema2 = await start(c, const MistakesPractice(2));
        expect([for (final q in onlyTema2.session!.questions) q.id], [t2.id]);

        await controller(c, const MistakesPractice(2)).answer(t2.answer);
        final attempts = await c.read(attemptRepositoryProvider).all();
        final review = attempts.where((a) => a.mode == AttemptMode.review);
        expect(review, hasLength(1));
        expect(review.single.questionId, t2.id);
        expect(review.single.correct, isTrue);
      },
    );

    test('no mistakes: an empty state, not a crash', () async {
      final c = makeStudyContainer();
      final state = await start(c, const MistakesPractice());
      expect(state.isEmpty, isTrue);
      expect(state.session, isNull);
      // Nothing to do: these must not throw.
      await controller(c, const MistakesPractice()).answer(0);
      controller(c, const MistakesPractice()).next();
    });
  });

  group('mock mistakes source', () {
    /// Starts a mock and hands it in with the questions at [wrong] answered
    /// wrongly, those at [blank] left blank and the rest right. Returns the
    /// mock id and its questions in exam order.
    Future<(int, List<Question>)> finishedMock(
      ProviderContainer c, {
      Set<int> wrong = const {},
      Set<int> blank = const {},
    }) async {
      final service = c.read(mockServiceProvider);
      final mock = await service.startMock(timed: false);
      var session = QuizSession(
        questions: mock.questions,
        mode: AttemptMode.mock,
      );
      for (var i = 0; i < session.length; i++) {
        if (blank.contains(i)) continue;
        final q = mock.questions[i];
        session = session
            .goTo(i)
            .select(wrong.contains(i) ? wrongOption(q) : q.answer);
      }
      await service.finishMock(mock.id, session.submit());
      await settle();
      return (mock.id, mock.questions);
    }

    test(
      'only the wrong and blank questions of that mock, in exam order',
      () async {
        final c = makeStudyContainer();
        final (otherId, otherQuestions) = await finishedMock(c, wrong: {0, 5});
        final (id, questions) = await finishedMock(
          c,
          wrong: {2, 9, 17},
          blank: {4},
        );

        final state = await start(c, MockMistakesPractice(id));
        final session = state.session!;
        expect(session.mode, AttemptMode.review);
        expect(
          [for (final q in session.questions) q.id],
          [
            for (final i in [2, 4, 9, 17]) questions[i].id,
          ],
        );
        expect(session.length, 4);
        expect(session.currentIndex, 0);

        // The other mock has its own list ...
        final other = (await start(c, MockMistakesPractice(otherId))).session!;
        expect(
          [for (final q in other.questions) q.id],
          [
            for (final i in [0, 5]) otherQuestions[i].id,
          ],
        );
        // ... and the global Fallos list holds all of them, which is what the
        // old button reviewed.
        final all = await c.read(mistakesProvider(null).future);
        expect(all.length, greaterThan(session.length));
      },
    );

    test(
      'answering stores review attempts and works like any session',
      () async {
        final c = makeStudyContainer();
        final (id, _) = await finishedMock(c, wrong: {1}, blank: {3});
        final source = MockMistakesPractice(id);
        final session = (await start(c, source)).session!;
        expect(session.length, 2);

        final ctrl = controller(c, source);
        await ctrl.answer(session.currentQuestion.answer);
        ctrl.next();
        await ctrl.answer(
          wrongOption(current(c, source).session!.currentQuestion),
        );
        ctrl.next();
        expect(current(c, source).finished, isTrue);

        final attempts = await c.read(attemptRepositoryProvider).all();
        final review = attempts.where((a) => a.mode == AttemptMode.review);
        expect(review, hasLength(2));
      },
    );

    test(
      'a perfect mock, an unfinished one and an unknown id are empty',
      () async {
        final c = makeStudyContainer();
        final (perfect, _) = await finishedMock(c);
        expect((await start(c, MockMistakesPractice(perfect))).isEmpty, isTrue);

        final open = await c.read(mockServiceProvider).startMock(timed: false);
        expect((await start(c, MockMistakesPractice(open.id))).isEmpty, isTrue);

        expect(
          (await start(c, const MockMistakesPractice(9999))).isEmpty,
          isTrue,
        );
      },
    );
  });

  group('PracticeSource', () {
    test('MockMistakesPractice compares by mock id', () {
      expect(const MockMistakesPractice(4), const MockMistakesPractice(4));
      expect(
        const MockMistakesPractice(4).hashCode,
        const MockMistakesPractice(4).hashCode,
      );
      expect(
        const MockMistakesPractice(4),
        isNot(const MockMistakesPractice(5)),
      );
      expect(const MockMistakesPractice(4), isNot(const MistakesPractice(4)));
      expect(
        const MockMistakesPractice(4).toString(),
        'MockMistakesPractice(4)',
      );
    });

    test('value equality, so the family key works', () {
      expect(const TemaPractice(1), const TemaPractice(1));
      expect(const TemaPractice(1), isNot(const TemaPractice(2)));
      expect(const DailyPractice(), const DailyPractice());
      expect(const MistakesPractice(), const MistakesPractice(null));
      expect(const MistakesPractice(3), isNot(const MistakesPractice()));
      expect(const TemaPractice(1), isNot(const MistakesPractice(1)));
      expect(const TemaPractice(1).hashCode, const TemaPractice(1).hashCode);
    });

    test(
      'temaPracticeOrder: first unanswered to the end, else everything',
      () async {
        final c = makeStudyContainer();
        final bank = await c.read(questionsProvider.future);
        final t7 = bank.where((q) => q.tema == 7).toList();
        expect(temaPracticeOrder(t7, {}), t7);
        expect(temaPracticeOrder(t7, {t7[0].id, t7[1].id}), t7.sublist(2));
        // A gap: the later answered one is practised again.
        expect(temaPracticeOrder(t7, {t7[0].id, t7[2].id}), t7.sublist(1));
        expect(temaPracticeOrder(t7, {for (final q in t7) q.id}), t7);
        expect(temaPracticeOrder(t7, {t7[3].id}), t7);
      },
    );
  });
}
