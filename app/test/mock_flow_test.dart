import 'dart:convert';
import 'dart:math';

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/same_stem_groups.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/application/mock_service.dart';
import 'package:apto_armas/features/mock/domain/mock_config.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/quiz_session.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/db_support.dart';
import 'support/study_support.dart';

/// A submitted mock where the first [right] questions are answered right,
/// the next [wrong] wrong, and the rest left blank.
QuizSession submittedMock(StartedMock mock, {int right = 0, int wrong = 0}) {
  var session = QuizSession(questions: mock.questions, mode: AttemptMode.mock);
  for (var i = 0; i < session.length; i++) {
    final q = session.questions[i];
    if (i < right) {
      session = session.goTo(i).select(q.answer);
    } else if (i < right + wrong) {
      session = session.goTo(i).select(wrongOption(q));
    }
  }
  return session.submit();
}

void main() {
  group('startMock', () {
    test('20 questions split 3/3/3/4/3/3/1, stored as an open mock', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);

      final mock = await service.startMock(timed: true);

      expect(mock.questions, hasLength(20));
      expect(mock.config, MockConfig());
      expect(mock.timed, isTrue);
      final byTema = <int, int>{};
      for (final q in mock.questions) {
        byTema[q.tema] = (byTema[q.tema] ?? 0) + 1;
      }
      expect(byTema, {1: 3, 2: 3, 3: 3, 4: 4, 5: 3, 6: 3, 7: 1});

      final row = (await c.read(mockRepositoryProvider).byId(mock.id))!;
      expect(row.questionIds, [for (final q in mock.questions) q.id]);
      expect(row.answers, everyElement(isNull));
      expect(row.answers, hasLength(20));
      expect(row.isFinished, isFalse);
      expect(row.correct, isNull);
      expect(row.passed, isNull);
      expect(row.timed, isTrue);
      expect(row.startedAt.isAtSameMomentAs(kStudyNow), isTrue);
    });

    test('never holds two questions with the same stem', () async {
      final c = makeStudyContainer();
      final questions = await c.read(questionsProvider.future);
      final groups = sameStemGroups(questions);
      expect(groups, isNotEmpty); // the real bank has 7 such pairs
      expect(await c.read(exclusionGroupsProvider.future), groups);

      final service = c.read(mockServiceProvider);
      for (var seed = 0; seed < 40; seed++) {
        final mock = await service.startMock(timed: false, rng: Random(seed));
        final ids = {for (final q in mock.questions) q.id};
        for (final group in groups) {
          expect(
            group.intersection(ids).length,
            lessThan(2),
            reason: 'seed $seed picked a pair of $group',
          );
        }
      }
    });

    test('the same seed gives the same mock', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);
      final a = await service.startMock(timed: false, rng: Random(7));
      final b = await service.startMock(timed: false, rng: Random(7));
      expect(a.id, isNot(b.id));
      expect(
        [for (final q in b.questions) q.id],
        [for (final q in a.questions) q.id],
      );
    });

    test('consecutive finished mocks share no questions', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);

      final first = await service.startMock(timed: false);
      await service.finishMock(first.id, submittedMock(first, right: 20));
      final second = await service.startMock(timed: false);
      await service.finishMock(second.id, submittedMock(second, right: 20));
      final third = await service.startMock(timed: false);

      Set<String> ids(StartedMock m) => {for (final q in m.questions) q.id};
      expect(ids(first).intersection(ids(second)), isEmpty);
      // avoidLastMocks = 2: the third avoids both previous ones.
      expect(ids(third).intersection(ids(first)), isEmpty);
      expect(ids(third).intersection(ids(second)), isEmpty);

      final recent = await c.read(mockRepositoryProvider).recentQuestionIds(2);
      expect(recent, [
        [for (final q in second.questions) q.id],
        [for (final q in first.questions) q.id],
      ]);
    });

    test('an abandoned (unfinished) mock does not count as recent', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);
      final abandoned = await service.startMock(timed: false);
      expect(
        await c.read(mockRepositoryProvider).recentQuestionIds(5),
        isEmpty,
      );
      expect(await c.read(mockRepositoryProvider).history(5), isEmpty);
      expect(abandoned.id, isPositive);
    });

    test('in-progress answers are saved', () async {
      final c = makeStudyContainer();
      final mock = await c.read(mockServiceProvider).startMock(timed: false);
      final repo = c.read(mockRepositoryProvider);
      final answers = <int?>[1, null, ...List<int?>.filled(18, 0)];

      await repo.saveAnswers(mock.id, answers);
      expect((await repo.byId(mock.id))!.answers, answers);
      await expectLater(
        repo.saveAnswers(mock.id, [1]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('mockConfigProvider', () {
    test('defaults when the manifest has no mock block', () async {
      final c = makeStudyContainer();
      expect(await c.read(mockConfigProvider.future), MockConfig());
    });

    test('uses the manifest mock block when present', () async {
      final bundle = FakeAssetBundle.real();
      final key = bundle.assets.keys.firstWhere(
        (k) => k.endsWith('manifest.json'),
      );
      final manifest =
          jsonDecode(utf8.decode(bundle.assets[key]!)) as Map<String, dynamic>;
      manifest['mock'] = {'size': 10, 'pass_mark': 8};
      bundle.assets[key] = utf8.encoder.convert(jsonEncode(manifest));

      final c = makeStudyContainer(bundle: bundle);
      final config = await c.read(mockConfigProvider.future);
      expect((config.size, config.passMark), (10, 8));

      final mock = await c.read(mockServiceProvider).startMock(timed: false);
      expect(mock.questions, hasLength(10));
      expect(mock.config, config);
    });
  });

  group('finishMock', () {
    test('16 correct passes (APTO) and is stored', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);
      final mock = await service.startMock(timed: false);

      final result = await service.finishMock(
        mock.id,
        submittedMock(mock, right: 16, wrong: 4),
      );

      expect((result.correct, result.passed), (16, true));
      final row = (await c.read(mockRepositoryProvider).byId(mock.id))!;
      expect(row.isFinished, isTrue);
      expect(row.finishedAt!.isAtSameMomentAs(kStudyNow), isTrue);
      expect((row.correct, row.passed), (16, true));
      expect(row.answers.where((a) => a != null), hasLength(20));
    });

    test(
      '15 correct does not pass; blanks are wrong attempts with the mock id',
      () async {
        final c = makeStudyContainer();
        final service = c.read(mockServiceProvider);
        final mock = await service.startMock(timed: false);

        final result = await service.finishMock(
          mock.id,
          submittedMock(mock, right: 15, wrong: 3), // 2 blank
        );

        expect((result.correct, result.wrong, result.unanswered), (15, 5, 2));
        expect(result.passed, isFalse);
        final row = (await c.read(mockRepositoryProvider).byId(mock.id))!;
        expect((row.correct, row.passed), (15, false));
        expect(row.answers.where((a) => a == null), hasLength(2));

        final attempts = await c.read(attemptRepositoryProvider).all();
        expect(attempts, hasLength(20));
        expect(attempts.every((a) => a.mockId == mock.id), isTrue);
        expect(attempts.every((a) => a.mode == AttemptMode.mock), isTrue);
        expect(attempts.where((a) => a.correct), hasLength(15));
        final blanks = attempts.where((a) => a.selected == null);
        expect(blanks, hasLength(2));
        expect(blanks.every((a) => !a.correct), isTrue);

        // Blank answers move SRS cards too, as a miss (box 1).
        final srs = c.read(srsRepositoryProvider);
        final blankId = blanks.first.questionId;
        expect((await srs.get(blankId))!.box, 1);
        expect(await srs.all(), hasLength(20));
      },
    );

    test('mockCountProvider counts finished mocks only', () async {
      final c = makeStudyContainer();
      final service = c.read(mockServiceProvider);
      expect(await c.read(mockCountProvider.future), 0);

      final first = await service.startMock(timed: false);
      await settle();
      expect(await c.read(mockCountProvider.future), 0); // still open

      await service.finishMock(first.id, submittedMock(first, right: 20));
      await settle();
      expect(await c.read(mockCountProvider.future), 1);

      final second = await service.startMock(timed: false);
      await service.finishMock(second.id, submittedMock(second, right: 10));
      await settle();
      expect(await c.read(mockCountProvider.future), 2);

      final history = await c.read(mockHistoryProvider.future);
      expect(history.map((m) => m.id), [second.id, first.id]);
    });

    test(
      'rejects a non-mock, an unsubmitted, a foreign or a repeated finish',
      () async {
        final c = makeStudyContainer();
        final service = c.read(mockServiceProvider);
        final mock = await service.startMock(timed: false);
        final other = await service.startMock(timed: false, rng: Random(99));

        final practice = QuizSession(
          questions: mock.questions,
          mode: AttemptMode.practice,
        );
        await expectLater(
          service.finishMock(mock.id, practice),
          throwsA(isA<ArgumentError>()),
        );
        final open = QuizSession(
          questions: mock.questions,
          mode: AttemptMode.mock,
        );
        await expectLater(
          service.finishMock(mock.id, open),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          service.finishMock(other.id, submittedMock(mock, right: 20)),
          throwsA(isA<ArgumentError>()),
        );
        await expectLater(
          service.finishMock(9999, submittedMock(mock, right: 20)),
          throwsA(isA<ArgumentError>()),
        );

        await service.finishMock(mock.id, submittedMock(mock, right: 20));
        await expectLater(
          service.finishMock(mock.id, submittedMock(mock, right: 20)),
          throwsA(isA<StateError>()),
        );
        // Only the one real finish recorded attempts.
        expect(await c.read(attemptRepositoryProvider).all(), hasLength(20));
      },
    );

    test(
      'is atomic: a failure leaves the mock open and nothing recorded',
      () async {
        final c = makeStudyContainer();
        final real = c.read(mockServiceProvider);
        final mock = await real.startMock(timed: false);
        final session = submittedMock(mock, right: 16, wrong: 4);

        // Same wiring as the real service, but the 10th SRS write fails, after
        // the mock row was updated and the 20 attempts inserted.
        final broken = MockService(
          db: c.read(appDatabaseProvider),
          mocks: c.read(mockRepositoryProvider),
          study: failingStudyService(c, failOn: 10),
          loadQuestions: () => c.read(questionsProvider.future),
          loadConfig: () => c.read(mockConfigProvider.future),
          loadExclusionGroups: () => c.read(exclusionGroupsProvider.future),
          clock: c.read(clockProvider),
          rng: Random(1),
        );

        await expectLater(
          broken.finishMock(mock.id, session),
          throwsA(isA<StateError>()),
        );

        final row = (await c.read(mockRepositoryProvider).byId(mock.id))!;
        expect(row.isFinished, isFalse);
        expect((row.correct, row.passed), (null, null));
        expect(row.answers, everyElement(isNull));
        expect(await c.read(attemptRepositoryProvider).all(), isEmpty);
        expect(await c.read(srsRepositoryProvider).all(), isEmpty);
        expect(await c.read(mockRepositoryProvider).history(5), isEmpty);

        // The mock can still be finished afterwards.
        final result = await real.finishMock(mock.id, session);
        expect(result.passed, isTrue);
        expect(await c.read(attemptRepositoryProvider).all(), hasLength(20));
      },
    );
  });
}
