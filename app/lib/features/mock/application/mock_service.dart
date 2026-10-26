import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show immutable;

import '../../../core/database/app_database.dart';
import '../../content/domain/question.dart';
import '../../quiz/application/study_service.dart';
import '../../quiz/domain/attempt.dart';
import '../../quiz/domain/quiz_session.dart';
import '../data/mock_repository.dart';
import '../domain/mock_config.dart';
import '../domain/mock_generator.dart';
import '../domain/mock_result.dart';

/// A mock that has just been created and stored.
@immutable
class StartedMock {
  const StartedMock({
    required this.id,
    required this.questions,
    required this.config,
    required this.timed,
  });

  /// Row id in `mocks`; pass it back to `MockService.finishMock`.
  final int id;

  /// In exam order (tema ascending). Build the session with
  /// `QuizSession(questions: questions, mode: AttemptMode.mock)`.
  final List<Question> questions;
  final MockConfig config;
  final bool timed;
}

/// Creates and closes mock exams (plan 2.4).
class MockService {
  MockService({
    required this._db,
    required this._mocks,
    required this._study,
    required this._loadQuestions,
    required this._loadConfig,
    required this._loadExclusionGroups,
    required this._clock,
    required this._rng,
  });

  final AppDatabase _db;
  final MockRepository _mocks;
  final StudyService _study;
  final Future<List<Question>> Function() _loadQuestions;
  final Future<MockConfig> Function() _loadConfig;
  final Future<List<Set<String>>> Function() _loadExclusionGroups;

  final DateTime Function() _clock;
  final Random _rng;

  /// Generates a mock from the active bank and stores it (unfinished, blank
  /// answer sheet).
  ///
  /// Avoids the questions of the last `config.avoidLastMocks` **finished**
  /// mocks (an abandoned mock does not count) and never puts two questions of
  /// the same stem group together. [rng] overrides the injected random source
  /// (tests pass a seeded one).
  ///
  /// With [replaceUnfinishedId] that one mock, if it is still open, is
  /// discarded (in the same transaction) in favour of the new one; the caller
  /// names the mock it showed the user and asked about, and no other mock is
  /// touched.
  Future<StartedMock> startMock({
    required bool timed,
    Random? rng,
    int? replaceUnfinishedId,
  }) async {
    final questions = await _loadQuestions();
    final config = await _loadConfig();
    final groups = await _loadExclusionGroups();
    final recent = await _mocks.recentQuestionIds(config.avoidLastMocks);
    final mock = generateMock(
      questions: questions,
      config: config,
      rng: rng ?? _rng,
      recentMocks: recent,
      exclusionGroups: groups,
    );
    final id = await _mocks.start(
      mock,
      timed: timed,
      startedAt: _clock(),
      replaceUnfinishedId: replaceUnfinishedId,
    );
    return StartedMock(id: id, questions: mock, config: config, timed: timed);
  }

  /// Closes mock [mockId] with a handed-in [session]: stores the final
  /// answers and score, and records every question as an attempt (blank ones
  /// as misses), all in **one transaction**. If any step fails nothing is
  /// written and the mock stays open.
  ///
  /// Throws [ArgumentError] for a non-mock or unknown/mismatching session,
  /// and [StateError] when the session was not submitted or the mock is
  /// already finished (finishing twice would duplicate the attempts).
  Future<MockResult> finishMock(int mockId, QuizSession session) async {
    if (session.mode != AttemptMode.mock) {
      throw ArgumentError.value(session, 'session', 'not a mock session');
    }
    if (!session.submitted) {
      throw StateError('Submit the mock before finishing it.');
    }
    final config = await _loadConfig(); // outside the transaction
    final now = _clock();
    return _db.transaction(() async {
      final record = await _mocks.byId(mockId);
      if (record == null) {
        throw ArgumentError.value(mockId, 'mockId', 'No such mock');
      }
      if (record.isFinished) {
        throw StateError('Mock $mockId is already finished.');
      }
      final ids = [for (final question in session.questions) question.id];
      if (ids.length != record.questionIds.length ||
          !_sameOrder(ids, record.questionIds)) {
        throw ArgumentError.value(
          session,
          'session',
          'questions differ from the stored mock $mockId',
        );
      }
      final result = scoreMock(
        questions: session.questions,
        answers: session.answers,
        config: config,
      );
      await _mocks.finish(mockId, result, session.answers, now);
      await _study.recordAnswers(session.toAttempts(now: now, mockId: mockId));
      return result;
    });
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
