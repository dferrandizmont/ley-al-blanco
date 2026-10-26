import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/mistakes/application/mistakes_providers.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/quiz_session.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/study_support.dart';

void main() {
  group('QuestionRepository', () {
    test('active() is the real bank in bank order, cached in memory', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      expect(questions, hasLength(423));
      expect(questions.first.id, 't1-001');
      expect(questions.last.tema, 7);

      final repo = c.read(questionRepositoryProvider);
      expect(identical(await repo.active(), await repo.active()), isTrue);
      expect(() => questions.add(questions.first), throwsUnsupportedError);
    });

    test('byTema and byIds (requested order, unknown skipped)', () async {
      final c = makeStudyContainer();
      await c.read(questionsProvider.future);
      final repo = c.read(questionRepositoryProvider);

      final tema7 = await repo.byTema(7);
      expect(tema7, hasLength(22));
      expect(tema7.every((q) => q.tema == 7), isTrue);

      final byIds = await repo.byIds(['t3-002', 'nope', 't1-001']);
      expect(byIds.map((q) => q.id), ['t3-002', 't1-001']);
    });
  });

  group('practice flow', () {
    test(
      'answers go through QuizSession and are stored with SRS cards',
      () async {
        final c = makeStudyContainer();
        final questions = await c.read(questionsProvider.future);
        final picked = questions.take(2).toList();

        var session = QuizSession(
          questions: picked,
          mode: AttemptMode.practice,
        );
        session = session.select(picked[0].answer).next(); // correct
        session = session.select(wrongOption(picked[1])); // wrong
        expect(session.isFinished, isTrue);

        await c
            .read(studyServiceProvider)
            .recordAnswers(session.toAttempts(now: kStudyNow));

        final stored = await c.read(attemptRepositoryProvider).all();
        expect(stored.map((a) => (a.questionId, a.mode, a.correct)), [
          (picked[0].id, AttemptMode.practice, true),
          (picked[1].id, AttemptMode.practice, false),
        ]);

        final srs = c.read(srsRepositoryProvider);
        final right = await srs.get(picked[0].id);
        final wrong = await srs.get(picked[1].id);
        expect(right!.box, 2); // new + correct
        expect(right.reps, 1);
        expect(right.lapses, 0);
        expect(right.lastAnsweredAt.isAtSameMomentAs(kStudyNow), isTrue);
        expect(wrong!.box, 1); // new + wrong
        expect(wrong.lapses, 0); // no card before, so not a lapse
        expect(await srs.get('t9-999'), isNull);
      },
    );

    test(
      'later answers move the same card (box up, lapse back to 1)',
      () async {
        final c = makeStudyContainer();
        final q = (await c.read(questionsProvider.future)).first;
        final study = c.read(studyServiceProvider);
        final srs = c.read(srsRepositoryProvider);

        await study.recordAnswers([
          attemptOn(q, correct: true, mode: AttemptMode.srs),
        ]);
        await study.recordAnswers([
          attemptOn(
            q,
            correct: true,
            at: kStudyNow.add(const Duration(minutes: 1)),
            mode: AttemptMode.review,
          ),
        ]);
        expect((await srs.get(q.id))!.box, 3);

        await study.recordAnswers([
          attemptOn(
            q,
            correct: false,
            at: kStudyNow.add(const Duration(minutes: 2)),
          ),
        ]);
        final card = (await srs.get(q.id))!;
        expect((card.box, card.lapses, card.reps), (1, 1, 3));
        expect(
          (await c.read(attemptRepositoryProvider).forQuestion(q.id))
              .map((a) => a.mode),
          [AttemptMode.srs, AttemptMode.review, AttemptMode.practice],
        );
      },
    );

    test('attempts reach SRS in answeredAt order, not list order', () async {
      final c = makeStudyContainer();
      final q = (await c.read(questionsProvider.future)).first;
      // Listed wrong-then-correct, but answered correct-then-wrong.
      await c.read(studyServiceProvider).recordAnswers([
        attemptOn(
          q,
          correct: false,
          at: kStudyNow.add(const Duration(minutes: 1)),
        ),
        attemptOn(q, correct: true),
      ]);
      final card = (await c.read(srsRepositoryProvider).get(q.id))!;
      expect((card.box, card.lapses, card.reps), (1, 1, 2));
    });

    test('an empty list is a no-op', () async {
      final c = makeStudyContainer();
      await c.read(questionsProvider.future);
      await c.read(studyServiceProvider).recordAnswers(const []);
      expect(await c.read(attemptRepositoryProvider).all(), isEmpty);
    });

    test('attempts and cards providers re-emit after recording', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      expect(await c.read(attemptsProvider.future), isEmpty);
      expect(await c.read(srsCardsProvider.future), isEmpty);

      await c.read(studyServiceProvider).recordAnswers([
        attemptOn(questions[0], correct: true),
      ]);
      await settle();

      expect(await c.read(attemptsProvider.future), hasLength(1));
      expect(
        (await c.read(srsCardsProvider.future)).map((card) => card.questionId),
        [questions[0].id],
      );
    });
  });

  group('recordAnswers atomicity', () {
    test('a failing SRS write leaves no attempts and no cards', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      final study = failingStudyService(c, failOn: 3);

      await expectLater(
        study.recordAnswers([
          for (final q in questions.take(5)) attemptOn(q, correct: true),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(await c.read(attemptRepositoryProvider).all(), isEmpty);
      expect(await c.read(srsRepositoryProvider).all(), isEmpty);
    });
  });

  group('Fallos across modes', () {
    test(
      'a mock miss enters Fallos (all / by tema); two correct answers clear it',
      () async {
        final c = makeStudyContainer();
        final mocks = c.read(mockServiceProvider);
        final started = await mocks.startMock(timed: false);
        final missed = started.questions.first;
        final otherTema = missed.tema == 7 ? 1 : missed.tema + 1;

        var session = QuizSession(
          questions: started.questions,
          mode: AttemptMode.mock,
        );
        for (var i = 0; i < session.length; i++) {
          final q = session.questions[i];
          session = session.goTo(i).select(i == 0 ? wrongOption(q) : q.answer);
        }
        await mocks.finishMock(started.id, session.submit());
        await settle();

        final all = await c.read(mistakesProvider(null).future);
        expect(all.map((e) => e.questionId), [missed.id]);
        expect(all.single.wrongCount, 1);
        expect(
          (await c.read(mistakesProvider(missed.tema).future))
              .map((e) => e.questionId),
          [missed.id],
        );
        expect(await c.read(mistakesProvider(otherTema).future), isEmpty);

        // The miss also dropped the question's SRS card to box 1.
        expect((await c.read(srsRepositoryProvider).get(missed.id))!.box, 1);

        // One correct practice answer is not enough...
        final study = c.read(studyServiceProvider);
        await study.recordAnswers([
          attemptOn(
            missed,
            correct: true,
            at: kStudyNow.add(const Duration(minutes: 1)),
          ),
        ]);
        await settle();
        final partial = await c.read(mistakesProvider(null).future);
        expect(partial.single.currentStreak, 1);

        // ...the second consecutive one clears it.
        await study.recordAnswers([
          attemptOn(
            missed,
            correct: true,
            at: kStudyNow.add(const Duration(minutes: 2)),
          ),
        ]);
        await settle();
        expect(await c.read(mistakesProvider(null).future), isEmpty);
        expect(await c.read(mistakesProvider(missed.tema).future), isEmpty);
      },
    );

    test('practice, review and srs misses all count', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      await c.read(studyServiceProvider).recordAnswers([
        attemptOn(questions[0], correct: false, mode: AttemptMode.practice),
        attemptOn(questions[1], correct: false, mode: AttemptMode.review),
        attemptOn(questions[2], correct: false, mode: AttemptMode.srs),
      ]);
      await settle();
      final ids = (await c.read(mistakesProvider(null).future))
          .map((e) => e.questionId);
      expect(
        ids,
        unorderedEquals([questions[0].id, questions[1].id, questions[2].id]),
      );
    });

    test('Fallos of a question that left the bank are hidden', () async {
      final c = makeStudyContainer();
      await c.read(questionsProvider.future);
      await c.read(studyServiceProvider).recordAnswers([
        Attempt(
          questionId: 't9-001',
          mode: AttemptMode.practice,
          selected: 0,
          correct: false,
          answeredAt: kStudyNow,
        ),
      ]);
      await settle();
      expect(await c.read(mistakesProvider(null).future), isEmpty);
    });
  });
}
