import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/mistakes/application/mistakes_providers.dart';
import 'package:apto_armas/features/progress/application/progress_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'support/study_support.dart';

Attempt _attemptAt(String id, DateTime at) => Attempt(
  questionId: id,
  mode: AttemptMode.practice,
  selected: 0,
  correct: true,
  answeredAt: at,
);

void main() {
  // One test compares two containers, hence two in-memory databases.
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('passProbabilityProvider', () {
    test('fresh install: every question at the 1/3 prior, about 0', () async {
      final c = makeStudyContainer();
      final p = await c.read(passProbabilityProvider.future);
      expect(p, lessThan(0.01));
      expect(p, greaterThanOrEqualTo(0));
    });

    test(
      'rises after correct answers, and is stable for the same data',
      () async {
        final c = makeStudyContainer();
        final questions = await c.read(questionsProvider.future);
        final before = await c.read(passProbabilityProvider.future);

        // Every question answered right once: p = 2/3 each.
        await c.read(studyServiceProvider).recordAnswers([
          for (final q in questions) attemptOn(q, correct: true),
        ]);
        await settle();

        final after = await c.read(passProbabilityProvider.future);
        expect(after, greaterThan(before));
        // Binomial(20, 2/3) tail at 16 is about 0.15; hypergeometric draws and
        // the fixed seed keep it in a loose band.
        expect(after, inInclusiveRange(0.05, 0.35));

        // Same data, recomputed: identical (fixed seed, no flicker).
        c.invalidate(passProbabilityProvider);
        expect(await c.read(passProbabilityProvider.future), after);

        // And identical in a brand new container with the same data.
        final other = makeStudyContainer();
        final otherQuestions = await other.read(questionsProvider.future);
        await other.read(studyServiceProvider).recordAnswers([
          for (final q in otherQuestions) attemptOn(q, correct: true),
        ]);
        expect(await other.read(passProbabilityProvider.future), after);
      },
    );

    test('goes down again after misses', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      final study = c.read(studyServiceProvider);
      await study.recordAnswers([
        for (final q in questions) attemptOn(q, correct: true),
      ]);
      await settle();
      final high = await c.read(passProbabilityProvider.future);

      await study.recordAnswers([
        for (final q in questions)
          attemptOn(
            q,
            correct: false,
            at: kStudyNow.add(const Duration(minutes: 1)),
          ),
      ]);
      await settle();
      expect(await c.read(passProbabilityProvider.future), lessThan(high));
    });
  });

  group('dailyQueueProvider', () {
    test(
      'fresh install: 15 new ids from tema 1 (ties go to the lowest tema)',
      () async {
        final c = makeStudyContainer();
        final questions = await c.read(questionsProvider.future);
        final queue = await c.read(dailyQueueProvider.future);

        final tema1 = [
          for (final q in questions)
            if (q.tema == 1) q.id,
        ];
        expect(queue, tema1.take(15).toList());
      },
    );

    test('after 5 new answers today the quota is 10 (+ due cards)', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      final queue = await c.read(dailyQueueProvider.future);
      final answered = queue.take(5).toList();
      final byId = {for (final q in questions) q.id: q};

      // 5 correct: box 2, due tomorrow, so nothing is due today.
      await c.read(studyServiceProvider).recordAnswers([
        for (final id in answered) attemptOn(byId[id]!, correct: true),
      ]);
      await settle();

      final next = await c.read(dailyQueueProvider.future);
      expect(next, hasLength(10));
      expect(next.toSet().intersection(answered.toSet()), isEmpty);
      // Tema 1 is now the best-mastered, so new questions come from tema 2.
      expect(next.map((id) => byId[id]!.tema).toSet(), {2});
    });

    test(
      'a miss is due again today and goes first, before the 10 new',
      () async {
        final c = makeStudyContainer();
        final questions = await c.read(questionsProvider.future);
        final byId = {for (final q in questions) q.id: q};
        final first5 = (await c.read(dailyQueueProvider.future))
            .take(5)
            .toList();

        await c.read(studyServiceProvider).recordAnswers([
          for (var i = 0; i < first5.length; i++)
            // Answered over 10 minutes ago: a miss from the last 10 minutes
            // would go behind the new ones (daily_queue.dart).
            attemptOn(
              byId[first5[i]]!,
              correct: i != 0,
              at: kStudyNow.subtract(const Duration(minutes: 15)),
            ),
        ]);
        await settle();

        final next = await c.read(dailyQueueProvider.future);
        expect(next, hasLength(11)); // 1 due + 10 new
        expect(next.first, first5.first);
        expect(next.skip(1).toSet().intersection(first5.toSet()), isEmpty);
      },
    );
  });

  group('newIntroducedToday', () {
    final today = DateTime(2026, 10, 15, 12);

    test('counts only questions whose FIRST attempt is today', () {
      final yesterday = DateTime(2026, 10, 14, 23, 59);
      final attempts = [
        _attemptAt('a', yesterday), // first seen yesterday...
        _attemptAt('a', today), // ...so answering again today is not new
        _attemptAt('b', today),
        _attemptAt('b', today.add(const Duration(hours: 1))), // counted once
        _attemptAt('c', today),
        _attemptAt('gone', today), // not in the bank
      ];
      expect(
        newIntroducedToday(
          attempts: attempts,
          activeIds: {'a', 'b', 'c'},
          now: today,
        ),
        2,
      );
    });

    test('does not depend on the order of the attempts', () {
      final attempts = [
        _attemptAt('a', today),
        _attemptAt('a', DateTime(2026, 10, 14, 10)),
      ];
      expect(
        newIntroducedToday(attempts: attempts, activeIds: {'a'}, now: today),
        0,
      );
    });
  });

  group('tema progress', () {
    test(
      'temaMastery, coverage and masteryById change after answering',
      () async {
        final c = makeStudyContainer();
        final questions = await c.read(questionsProvider.future);
        final tema3 = questions.where((q) => q.tema == 3).toList();

        final before = await c.read(temaMasteryProvider.future);
        expect(before.keys, [1, 2, 3, 4, 5, 6, 7]);
        for (final mastery in before.values) {
          expect(mastery, closeTo(1 / 3, 1e-9));
        }
        expect((await c.read(coverageProvider.future)).values, everyElement(0));

        await c.read(studyServiceProvider).recordAnswers([
          for (final q in tema3.take(10)) attemptOn(q, correct: true),
        ]);
        await settle();

        final after = await c.read(temaMasteryProvider.future);
        expect(after[3]!, greaterThan(before[3]!));
        // 10 of 66 questions went from 1/3 to 2/3.
        expect(after[3]!, closeTo(1 / 3 + 10 / 66 / 3, 1e-9));
        for (final tema in [1, 2, 4, 5, 6, 7]) {
          expect(after[tema]!, closeTo(1 / 3, 1e-9));
        }

        final covered = await c.read(coverageProvider.future);
        expect(covered[3], closeTo(10 / 66, 1e-9));
        expect(covered[1], 0);

        final byId = await c.read(masteryByIdProvider.future);
        expect(byId[tema3.first.id], closeTo(2 / 3, 1e-9));
        expect(byId[tema3.last.id], closeTo(1 / 3, 1e-9));
      },
    );

    test(
      'temaSummaryProvider combines questions, mastery, coverage and Fallos',
      () async {
        final c = makeStudyContainer();
        final questions = await c.read(questionsProvider.future);
        final tema2 = questions.where((q) => q.tema == 2).toList();

        final fresh = await c.read(temaSummaryProvider.future);
        expect(fresh.map((s) => s.tema), [1, 2, 3, 4, 5, 6, 7]);
        expect(fresh.map((s) => s.questionCount), [68, 67, 66, 70, 66, 64, 22]);
        expect(
          fresh.every((s) => s.mistakesCount == 0 && s.coverage == 0),
          isTrue,
        );

        await c.read(studyServiceProvider).recordAnswers([
          attemptOn(tema2[0], correct: false),
          attemptOn(tema2[1], correct: true),
        ]);
        await settle();

        final summary = await c.read(temaSummaryProvider.future);
        final two = summary.firstWhere((s) => s.tema == 2);
        expect(two.mistakesCount, 1);
        expect(two.coverage, closeTo(2 / 67, 1e-9));
        expect(two.mastery, isNot(closeTo(1 / 3, 1e-6)));
        expect(summary.firstWhere((s) => s.tema == 1).mistakesCount, 0);
        expect(
          (await c.read(mistakesProvider(2).future)).map((e) => e.questionId),
          [tema2[0].id],
        );
      },
    );
  });
}
