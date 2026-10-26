import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/daily/application/daily_providers.dart';
import 'package:apto_armas/features/daily/data/daily_repository.dart';
import 'package:apto_armas/features/daily/domain/daily_question.dart';
import 'package:apto_armas/features/daily/presentation/daily_question_card.dart';
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

Question _question(String id, int tema) => Question(
  id: id,
  tema: tema,
  stem: 'Enunciado $id',
  options: const ['a', 'b', 'c'],
  answer: 0,
  edition: 'TEST',
);

void main() {
  group('days and the pick', () {
    test('isoDay is the local calendar day in ISO 8601', () {
      expect(isoDay(DateTime(2026, 10, 5, 23, 59)), '2026-10-05');
      expect(isoDay(DateTime(2026, 1, 31, 0, 0, 1)), '2026-01-31');
      // A UTC moment is read in local time, like the daily queue does.
      final utc = DateTime.utc(2026, 10, 15, 12);
      expect(isoDay(utc), isoDay(utc.toLocal()));
    });

    test('parseIsoDay accepts only real dates', () {
      expect(parseIsoDay('2026-10-15'), DateTime.utc(2026, 10, 15));
      expect(parseIsoDay('2024-02-29'), DateTime.utc(2024, 2, 29));
      for (final bad in [
        null,
        '',
        '2026-2-3',
        '2026-02-30',
        '2026-13-01',
        '15/10/2026',
        '2026-10-15T10:00',
      ]) {
        expect(parseIsoDay(bad), isNull, reason: '$bad');
      }
    });

    test('daysBetween counts calendar days (month, year, leap day)', () {
      DateTime d(String iso) => parseIsoDay(iso)!;
      expect(daysBetween(d('2026-10-15'), d('2026-10-16')), 1);
      expect(daysBetween(d('2026-12-31'), d('2027-01-01')), 1);
      expect(daysBetween(d('2028-02-28'), d('2028-03-01')), 2);
      expect(daysBetween(d('2026-10-15'), d('2026-10-15')), 0);
      expect(daysBetween(d('2026-10-16'), d('2026-10-15')), -1);
      // Across the end of daylight saving time (a 25-hour day in Madrid).
      expect(daysBetween(d('2026-10-24'), d('2026-10-26')), 2);
    });

    test('the pick is stable for a day and does not depend on the time', () {
      final bank = [for (var i = 1; i <= 68; i++) _question('t1-$i', 1)];
      final morning = pickDailyQuestion(bank, DateTime(2026, 10, 15, 0, 0, 1));
      final night = pickDailyQuestion(bank, DateTime(2026, 10, 15, 23, 59));
      expect(morning, isNotNull);
      expect(morning!.id, night!.id);
      // Same call, same answer (no randomness).
      expect(pickDailyQuestion(bank, DateTime(2026, 10, 15))!.id, morning.id);
    });

    test('the pick changes from day to day and covers the list', () {
      final bank = [for (var i = 1; i <= 30; i++) _question('t1-$i', 1)];
      final ids = {
        for (var d = 0; d < 400; d++)
          pickDailyQuestion(bank, DateTime(2026, 1, 1 + d))!.id,
      };
      expect(ids.length, greaterThan(25));
      final week = [
        for (var d = 0; d < 7; d++)
          pickDailyQuestion(bank, DateTime(2026, 10, 12 + d))!.id,
      ];
      expect(week.toSet().length, greaterThan(3));
    });

    test('an empty list has no question', () {
      expect(pickDailyQuestion(const [], DateTime(2026, 10, 15)), isNull);
    });
  });

  group('streak', () {
    final d1 = DateTime(2026, 10, 15, 9);

    test('the first answer starts a streak of one', () {
      final p = DailyProgress.none.afterAnswer(d1, 't1-001');
      expect(p.streak, 1);
      expect(p.lastDay, '2026-10-15');
      expect(p.lastQuestionId, 't1-001');
      expect(p.answeredOn(d1), isTrue);
      expect(p.streakOn(d1), 1);
    });

    test('answering again the same day changes nothing', () {
      final p = DailyProgress.none.afterAnswer(d1, 't1-001');
      final again = p.afterAnswer(DateTime(2026, 10, 15, 23, 59), 't1-002');
      expect(again, p);
      expect(again.lastQuestionId, 't1-001');
    });

    test('consecutive days add one, also across midnight and months', () {
      var p = DailyProgress.none.afterAnswer(
        DateTime(2026, 10, 30, 23, 59),
        'a',
      );
      p = p.afterAnswer(DateTime(2026, 10, 31, 0, 1), 'b');
      p = p.afterAnswer(DateTime(2026, 11, 1, 12), 'c');
      expect(p.streak, 3);
      expect(p.lastDay, '2026-11-01');
    });

    test('a skipped day: shows 0 and the next answer restarts at 1', () {
      final p = DailyProgress.none
          .afterAnswer(d1, 'a')
          .afterAnswer(DateTime(2026, 10, 16, 9), 'b');
      expect(p.streak, 2);
      // Alive the day after, and the whole of that day.
      expect(p.streakOn(DateTime(2026, 10, 17, 23, 59)), 2);
      expect(p.answeredOn(DateTime(2026, 10, 17)), isFalse);
      // Dead the day after that.
      expect(p.streakOn(DateTime(2026, 10, 18, 0, 1)), 0);
      expect(p.afterAnswer(DateTime(2026, 10, 18, 9), 'c').streak, 1);
    });

    test('a clock moved back restarts the streak instead of breaking', () {
      final p = DailyProgress.none.afterAnswer(DateTime(2026, 10, 20), 'a');
      expect(p.streakOn(DateTime(2026, 10, 10)), 0);
      final back = p.afterAnswer(DateTime(2026, 10, 10), 'b');
      expect(back.streak, 1);
      expect(back.lastDay, '2026-10-10');
    });

    test('a year change keeps the streak', () {
      final p = DailyProgress.none
          .afterAnswer(DateTime(2026, 12, 31, 20), 'a')
          .afterAnswer(DateTime(2027, 1, 1, 8), 'b');
      expect(p.streak, 2);
    });
  });

  group('persistence', () {
    test('the repository round-trips and ignores garbage', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = DailyRepository(db.settingsDao);
      expect(await repo.load(), DailyProgress.none);

      const saved = DailyProgress(
        lastDay: '2026-10-15',
        streak: 4,
        lastQuestionId: 't2-010',
      );
      await repo.save(saved);
      expect(await repo.load(), saved);

      // Unreadable values count as "never answered".
      await db.settingsDao.set(DailySettingKeys.lastDay, 'ayer');
      expect(await repo.load(), DailyProgress.none);
      await db.settingsDao.set(DailySettingKeys.lastDay, '2026-10-15');
      await db.settingsDao.set(DailySettingKeys.streak, '-3');
      expect(await repo.load(), DailyProgress.none);
    });

    test('the streak survives reopening the app (same database)', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      var now = DateTime(2026, 10, 15, 9);
      final first = makeStudyContainer(database: db, clock: () => now);
      await first.read(dailyProgressProvider.future);
      await first.read(dailyProgressProvider.notifier).register('t1-001');
      first.dispose();

      now = DateTime(2026, 10, 16, 9);
      final second = makeStudyContainer(database: db, clock: () => now);
      final progress = await second.read(dailyProgressProvider.future);
      expect(progress.streak, 1);
      expect(progress.lastQuestionId, 't1-001');
      await second.read(dailyProgressProvider.notifier).register('t1-002');
      expect((await second.read(dailyProgressProvider.future)).streak, 2);
    });
  });

  group("today's question and the access rules", () {
    test('once answered, the same question stays for the day', () async {
      var now = DateTime(2026, 10, 15, 9);
      final c = makeStudyContainer(clock: () => now);
      final before = await c.read(dailyStatusProvider.future);
      expect(before.answeredToday, isFalse);
      expect(before.streak, 0);
      await c
          .read(dailyProgressProvider.notifier)
          .register(before.question!.id);
      final after = await c.read(dailyStatusProvider.future);
      expect(after.answeredToday, isTrue);
      expect(after.question!.id, before.question!.id);
      expect(after.streak, 1);

      // Next day: a new question, still showing yesterday's streak.
      now = DateTime(2026, 10, 16, 8);
      c.invalidate(dailyStatusProvider);
      final next = await c.read(dailyStatusProvider.future);
      expect(next.answeredToday, isFalse);
      expect(next.streak, 1);

      // Skipping a whole day (the 16th) ends it on the 17th.
      now = DateTime(2026, 10, 17, 8);
      c.invalidate(dailyStatusProvider);
      expect((await c.read(dailyStatusProvider.future)).streak, 0);
    });

    test('answering stores the attempt and advances the streak', () async {
      var now = DateTime(2026, 10, 15, 9);
      final c = makeStudyContainer(clock: () => now);

      Future<Question> openToday() async {
        c.invalidate(dailyStatusProvider);
        final question = (await c.read(dailyStatusProvider.future)).question!;
        final source = DailyQuestionPractice(question.id);
        c.listen(practiceControllerProvider(source), (previous, next) {});
        final state = await c.read(practiceControllerProvider(source).future);
        expect(state.session!.length, 1);
        expect(state.session!.currentQuestion.id, question.id);
        return question;
      }

      Future<void> answer(Question question, int option) => c
          .read(
            practiceControllerProvider(DailyQuestionPractice(question.id))
                .notifier,
          )
          .answer(option);

      // A wrong answer counts for the streak too and lands in the attempts.
      final q1 = await openToday();
      await answer(q1, (q1.answer + 1) % 3);
      final attempts = await c.read(attemptsProvider.future);
      expect(attempts, hasLength(1));
      expect(attempts.single.mode, AttemptMode.practice);
      expect(attempts.single.correct, isFalse);
      expect((await c.read(dailyProgressProvider.future)).streak, 1);

      // Next day: the streak grows.
      now = DateTime(2026, 10, 16, 9);
      final q2 = await openToday();
      await answer(q2, q2.answer);
      expect((await c.read(dailyProgressProvider.future)).streak, 2);

      // Two days later (one skipped): shows 0, and answering starts again.
      now = DateTime(2026, 10, 19, 9);
      c.invalidate(dailyStatusProvider);
      expect((await c.read(dailyStatusProvider.future)).streak, 0);
      final q3 = await openToday();
      await answer(q3, q3.answer);
      expect((await c.read(dailyProgressProvider.future)).streak, 1);
    });
  });

  group('Inicio', () {
    testScreen('the card, the flow and the streak across days', (tester) async {
      var now = DateTime(2026, 10, 15, 9);
      await pumpFullApp(tester, clock: () => now);
      final container = containerOf(tester);
      final status = await container.read(dailyStatusProvider.future);
      final question = status.question!;
      await tester.pumpAndSettle();

      expect(find.byType(DailyQuestionCard), findsOneWidget);
      expect(find.text('PREGUNTA DEL DÍA'), findsOneWidget);
      expect(find.text(question.stem), findsOneWidget);
      expect(find.textContaining('Racha'), findsNothing);

      await tester.ensureVisible(find.text('Responder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Responder'));
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/pregunta-del-dia');
      expect(find.text('PREGUNTA DEL DÍA'), findsOneWidget);

      await tapOption(tester, question.answer);
      expect(find.text('Correcto'), findsOneWidget);
      // One question: "Terminar" goes straight back to Inicio.
      await tapNext(tester, label: 'Terminar');
      expect(locationOf(tester), '/');

      expect(find.text('Respondida hoy'), findsOneWidget);
      expect(find.text('Racha de 1 día'), findsOneWidget);
      expect(find.text('Responder'), findsNothing);
      expect(find.text(question.stem), findsNothing);

      // The next day: a new question, the streak is kept.
      now = DateTime(2026, 10, 16, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Respondida hoy'), findsNothing);
      expect(find.text('Responder'), findsOneWidget);
      expect(find.text('Racha de 1 día'), findsOneWidget);

      // Two days later without answering: the badge is gone.
      now = DateTime(2026, 10, 18, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('Racha'), findsNothing);
    });

    testScreen('the streak badge is announced to screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpFullApp(tester);
      final container = containerOf(tester);
      final question = (await container.read(dailyStatusProvider.future))
          .question!;
      await container
          .read(dailyProgressProvider.notifier)
          .register(question.id);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Racha de 1 día'), findsOneWidget);
      expect(
        find.text('Vuelve mañana para seguir con tu racha.'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
