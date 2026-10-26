import 'dart:async';

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/data/mock_repository.dart';
import 'package:apto_armas/features/mock/domain/mock_result.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_support.dart';
import 'support/study_support.dart';

/// Starts a stored mock and builds its controller (kept alive by a listener).
Future<(int, MockState)> open(ProviderContainer c, {bool timed = false}) async {
  final started = await c.read(mockServiceProvider).startMock(timed: timed);
  c.listen(mockControllerProvider(started.id), (previous, next) {});
  final state = await c.read(mockControllerProvider(started.id).future);
  return (started.id, state);
}

MockController controller(ProviderContainer c, int id) =>
    c.read(mockControllerProvider(id).notifier);

MockState current(ProviderContainer c, int id) =>
    c.read(mockControllerProvider(id)).requireValue;

/// Answers question [index] right ([right] true) or wrong.
void answer(ProviderContainer c, int id, int index, {required bool right}) {
  final ctrl = controller(c, id)..goTo(index);
  final q = current(c, id).session.currentQuestion;
  ctrl.select(right ? q.answer : wrongOption(q));
}

void main() {
  test('submit survives disposal while waiting for an answer save', () async {
    late _GatedAnswerRepository repository;
    final c = makeStudyContainer(
      overrides: [
        mockRepositoryProvider.overrideWith(
          (ref) => repository = _GatedAnswerRepository(
            ref.watch(appDatabaseProvider),
          ),
        ),
      ],
    );
    final started = await c.read(mockServiceProvider).startMock(timed: false);
    final provider = mockControllerProvider(started.id);
    final subscription = c.listen(provider, (previous, next) {});
    await c.read(provider.future);
    final ctrl = c.read(provider.notifier)..select(started.questions[0].answer);
    await repository.saving.future;

    final pending = ctrl.submit();
    subscription.close();
    await pumpEventQueue();
    repository.release.complete();

    expect((await pending).correct, 1);
    expect((await repository.byId(started.id))!.isFinished, isTrue);
    expect(await c.read(attemptRepositoryProvider).all(), hasLength(20));
  });

  test('opens a stored mock: 20 blank questions in mock mode', () async {
    final c = makeStudyContainer();
    final (id, state) = await open(c, timed: true);
    expect(state.mockId, id);
    expect(state.timed, isTrue);
    expect(state.startedAt.isAtSameMomentAs(kStudyNow), isTrue);
    expect(state.session.mode, AttemptMode.mock);
    expect(state.session.length, 20);
    expect(state.session.answeredCount, 0);
    expect(state.session.currentIndex, 0);
    expect(state.isSubmitted, isFalse);
    expect(state.session.hasImmediateFeedback, isFalse);
  });

  test('an unknown mock id is an error, not a crash', () async {
    final c = makeStudyContainer();
    c.listen(mockControllerProvider(999), (previous, next) {});
    await expectLater(
      c.read(mockControllerProvider(999).future),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('every change of answer is saved in the database', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    final ctrl = controller(c, id);
    final repo = c.read(mockRepositoryProvider);

    ctrl.select(1);
    await ctrl.pendingSaves;
    expect((await repo.byId(id))!.answers.first, 1);

    // Change of mind, then another question.
    ctrl.select(2);
    answer(c, id, 7, right: true);
    await ctrl.pendingSaves;
    final saved = (await repo.byId(id))!.answers;
    expect(saved[0], 2);
    expect(saved[7], current(c, id).session.questions[7].answer);
    expect(saved.where((a) => a != null), hasLength(2));
    expect((await repo.byId(id))!.isFinished, isFalse);
    // No attempts until the mock is handed in.
    expect(await c.read(attemptRepositoryProvider).all(), isEmpty);
  });

  test('picking the same option again does not write again', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    final ctrl = controller(c, id)..select(0);
    final before = current(c, id).session;
    ctrl.select(0);
    expect(identical(current(c, id).session, before), isTrue);
  });

  test('navigation: next, previous, goTo and the limits', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    final ctrl = controller(c, id);
    ctrl.previous();
    expect(current(c, id).session.currentIndex, 0);
    ctrl.next();
    ctrl.next();
    expect(current(c, id).session.currentIndex, 2);
    ctrl.previous();
    expect(current(c, id).session.currentIndex, 1);
    ctrl.goTo(19);
    expect(current(c, id).session.currentIndex, 19);
    ctrl.next(); // last: stays
    expect(current(c, id).session.currentIndex, 19);
    // Free navigation without answering anything.
    ctrl.goTo(5);
    expect(current(c, id).session.currentIndex, 5);
  });

  test('an interrupted mock comes back with its answers', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    final ctrl = controller(c, id);
    answer(c, id, 0, right: true);
    answer(c, id, 3, right: false);
    await ctrl.pendingSaves;

    // The controller goes away (screen closed); a new one reads the DB.
    c.invalidate(mockControllerProvider(id));
    final reopened = await c.read(mockControllerProvider(id).future);
    expect(reopened.session.answeredCount, 2);
    expect(reopened.session.answers[0], reopened.session.questions[0].answer);
    expect(
      reopened.session.answers[3],
      isNot(reopened.session.questions[3].answer),
    );
    expect(reopened.session.currentIndex, 0);
    expect(reopened.isSubmitted, isFalse);
  });

  test('submit: scores, stores the attempts, locks the session', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    for (var i = 0; i < 16; i++) {
      answer(c, id, i, right: true);
    }
    for (var i = 16; i < 18; i++) {
      answer(c, id, i, right: false);
    }
    // 18, 19 left blank.

    final result = await controller(c, id).submit();

    expect(result.correct, 16);
    expect(result.passed, isTrue);
    expect(result.unanswered, 2);
    final state = current(c, id);
    expect(state.isSubmitted, isTrue);
    expect(state.submitting, isFalse);

    final record = (await c.read(mockRepositoryProvider).byId(id))!;
    expect(record.isFinished, isTrue);
    expect(record.correct, 16);
    expect(record.passed, isTrue);

    // 20 attempts in mock mode, linked to the mock, blanks as misses.
    final attempts = await c.read(attemptRepositoryProvider).all();
    expect(attempts, hasLength(20));
    expect(
      attempts.every((a) => a.mode == AttemptMode.mock && a.mockId == id),
      isTrue,
    );
    expect(attempts.where((a) => !a.correct), hasLength(4));
    expect(attempts.where((a) => a.selected == null), hasLength(2));
    expect(await c.read(srsRepositoryProvider).all(), hasLength(20));

    // Read-only afterwards.
    final ctrl = controller(c, id);
    ctrl.select(0);
    ctrl.goTo(2);
    expect(current(c, id).session.currentIndex, state.session.currentIndex);
  });

  test('15 correct is not enough', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    for (var i = 0; i < 15; i++) {
      answer(c, id, i, right: true);
    }
    final result = await controller(c, id).submit();
    expect(result.correct, 15);
    expect(result.passed, isFalse);
  });

  test('a failing submit leaves the mock open and can be retried', () async {
    final c = makeStudyContainer(
      overrides: [
        srsRepositoryProvider.overrideWith(
          (ref) =>
              FailingSrsRepository(ref.watch(appDatabaseProvider), failOn: 3),
        ),
      ],
    );
    final (id, _) = await open(c);
    answer(c, id, 0, right: true);
    final ctrl = controller(c, id);

    await expectLater(ctrl.submit(), throwsStateError);
    final state = current(c, id);
    expect(state.isSubmitted, isFalse);
    expect(state.submitting, isFalse);
    expect(
      (await c.read(mockRepositoryProvider).byId(id))!.isFinished,
      isFalse,
    );
    expect(await c.read(attemptRepositoryProvider).all(), isEmpty);

    // Still usable: change an answer and hand in again (the failure was a
    // one-off).
    ctrl.select(1);
    final result = await ctrl.submit();
    expect(result.total, 20);
    expect((await c.read(mockRepositoryProvider).byId(id))!.isFinished, isTrue);
  });

  test('mockOutcomeProvider: score, questions and failed indices', () async {
    final c = makeStudyContainer();
    final (id, _) = await open(c);
    for (var i = 0; i < 17; i++) {
      answer(c, id, i, right: true);
    }
    answer(c, id, 17, right: false);
    await controller(c, id).submit();

    c.listen(mockOutcomeProvider(id), (previous, next) {});
    final outcome = (await c.read(mockOutcomeProvider(id).future))!;
    expect(outcome.result.correct, 17);
    expect(outcome.result.passed, isTrue);
    expect(outcome.questions, hasLength(20));
    expect(outcome.failedIndices, [17, 18, 19]);
    expect(
      outcome.result.perTema.values.fold<int>(0, (sum, t) => sum + t.total),
      20,
    );

    expect(await c.read(mockOutcomeProvider(12345).future), isNull);
  });

  test('a controller disposed while handing in does not throw', () async {
    late GatedMockService gated;
    final c = makeStudyContainer(
      overrides: [
        mockServiceProvider.overrideWith(
          (ref) => gated = GatedMockService(realMockService(ref)),
        ),
      ],
    );
    final started = await c.read(mockServiceProvider).startMock(timed: false);
    final id = started.id;
    final subscription = c.listen(
      mockControllerProvider(id),
      (previous, next) {},
    );
    await c.read(mockControllerProvider(id).future);
    for (var i = 0; i < 16; i++) {
      answer(c, id, i, right: true);
    }

    // "Entregar" is in flight when the last listener goes away: the
    // auto-dispose controller is gone before the transaction commits.
    final pending = controller(c, id).submit();
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();
    gated.gate.complete();

    final result = await pending; // must not throw on `state =`
    expect((result.correct, result.passed), (16, true));
    final record = (await c.read(mockRepositoryProvider).byId(id))!;
    expect(record.isFinished, isTrue);
    expect(record.passMark, 16);
  });

  test('a controller disposed before a failing hand-in rethrows it', () async {
    late GatedMockService gated;
    final c = makeStudyContainer(
      overrides: [
        mockServiceProvider.overrideWith(
          (ref) => gated = GatedMockService(realMockService(ref)),
        ),
      ],
    );
    final id = (await c.read(mockServiceProvider).startMock(timed: false)).id;
    final subscription = c.listen(
      mockControllerProvider(id),
      (previous, next) {},
    );
    await c.read(mockControllerProvider(id).future);
    gated.failure = StateError('disk full');

    final pending = controller(c, id).submit();
    final outcome = expectLater(pending, throwsStateError);
    await pumpEventQueue();
    subscription.close();
    await pumpEventQueue();
    gated.gate.complete();
    await outcome;
    expect(
      (await c.read(mockRepositoryProvider).byId(id))!.isFinished,
      isFalse,
    );
  });

  group('mockOutcomeProvider uses the stored verdict', () {
    // A mock handed in with pass mark 10: 12 right, 8 wrong.
    Future<(ProviderContainer, int)> finishedWithPassMark(
      int passMark, {
      bool store = true,
    }) async {
      final c = makeStudyContainer();
      final (id, _) = await open(c);
      for (var i = 0; i < 12; i++) {
        answer(c, id, i, right: true);
      }
      for (var i = 12; i < 20; i++) {
        answer(c, id, i, right: false);
      }
      await controller(c, id).pendingSaves;
      final repo = c.read(mockRepositoryProvider);
      final record = (await repo.byId(id))!;
      // The exam config at the time said 10; the app's current one says 16.
      final result = MockResult(
        correct: 12,
        wrong: 8,
        unanswered: 0,
        passed: 12 >= passMark,
        passMark: passMark,
        perTema: const {},
      );
      if (store) {
        await repo.finish(id, result, record.answers, kStudyNow);
      } else {
        // As written before schema v2: no pass mark column.
        await c
            .read(appDatabaseProvider)
            .mocksDao
            .finish(
              id,
              answers: record.answers,
              correctCount: 12,
              passed: true,
              finishedAt: kStudyNow,
            );
      }
      return (c, id);
    }

    test('a later pass-mark change does not flip an old verdict', () async {
      final (c, id) = await finishedWithPassMark(10);
      expect((await c.read(mockConfigProvider.future)).passMark, 16);

      c.listen(mockOutcomeProvider(id), (previous, next) {});
      final outcome = (await c.read(mockOutcomeProvider(id).future))!;
      expect(outcome.record.passMark, 10);
      expect(outcome.result.correct, 12);
      expect(outcome.result.passed, isTrue, reason: '12 >= 10 back then');
      expect(outcome.result.passMark, 10);
      expect(outcome.result.wrong, 8);
      // The per-tema breakdown is still recomputed from the answers.
      expect(
        outcome.result.perTema.values.fold<int>(0, (sum, t) => sum + t.total),
        20,
      );
      expect(
        outcome.result.perTema.values.fold<int>(0, (sum, t) => sum + t.correct),
        12,
      );
    });

    test('the stored NO APTO stays NO APTO under a laxer config', () async {
      final (c, id) = await finishedWithPassMark(18);
      c.listen(mockOutcomeProvider(id), (previous, next) {});
      final outcome = (await c.read(mockOutcomeProvider(id).future))!;
      expect(outcome.result.passed, isFalse);
      expect(outcome.result.passMark, 18);
    });

    test('a mock finished before v2 keeps its stored verdict', () async {
      final (c, id) = await finishedWithPassMark(10, store: false);
      c.listen(mockOutcomeProvider(id), (previous, next) {});
      final outcome = (await c.read(mockOutcomeProvider(id).future))!;
      expect(outcome.record.passMark, isNull);
      expect(outcome.result.correct, 12);
      // The stored verdict wins; the pass mark falls back to the current one.
      expect(outcome.result.passed, isTrue);
      expect(outcome.result.passMark, 16);
    });

    test('finishMock stores the pass mark it used', () async {
      final c = makeStudyContainer();
      final (id, _) = await open(c);
      await controller(c, id).submit();
      expect((await c.read(mockRepositoryProvider).byId(id))!.passMark, 16);
    });
  });
}

class _GatedAnswerRepository extends MockRepository {
  _GatedAnswerRepository(super.db);

  final saving = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> saveAnswers(int id, List<int?> answers) async {
    saving.complete();
    await release.future;
    await super.saveAnswers(id, answers);
  }
}
