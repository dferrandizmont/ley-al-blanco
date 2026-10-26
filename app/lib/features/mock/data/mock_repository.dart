import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../../../core/database/app_database.dart';
import '../../content/domain/question.dart';
import '../domain/mock_result.dart';

/// A stored mock exam: in progress (`finishedAt == null`) or finished.
@immutable
class MockRecord {
  const MockRecord({
    required this.id,
    required this.startedAt,
    required this.finishedAt,
    required this.questionIds,
    required this.answers,
    required this.correct,
    required this.passed,
    required this.timed,
    this.passMark,
    this.flagged = const [],
  });

  final int id;
  final DateTime startedAt;
  final DateTime? finishedAt;

  /// Exam order.
  final List<String> questionIds;

  /// One slot per question, null = left blank.
  final List<int?> answers;

  /// Right answers; null until finished.
  final int? correct;

  /// `APTO`; null until finished.
  final bool? passed;
  final bool timed;

  /// The pass mark that decided [passed]; null while unfinished and for
  /// mocks finished before schema v2 (unknown).
  final int? passMark;

  /// Ids of the questions the user marked as doubtful (exam order).
  final List<String> flagged;

  bool get isFinished => finishedAt != null;

  @override
  bool operator ==(Object other) =>
      other is MockRecord &&
      other.id == id &&
      other.startedAt == startedAt &&
      other.finishedAt == finishedAt &&
      listEquals(other.questionIds, questionIds) &&
      listEquals(other.answers, answers) &&
      other.correct == correct &&
      other.passed == passed &&
      other.passMark == passMark &&
      listEquals(other.flagged, flagged) &&
      other.timed == timed;

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    finishedAt,
    Object.hashAll(questionIds),
    Object.hashAll(answers),
    correct,
    passed,
    passMark,
    Object.hashAll(flagged),
    timed,
  );

  @override
  String toString() =>
      'MockRecord($id, finished: $isFinished, correct: $correct)';
}

/// Mock exams in the `mocks` table.
class MockRepository {
  MockRepository(this._db);

  final AppDatabase _db;

  /// Creates a mock with these questions (in this order) and an all-blank
  /// answer sheet. Returns its id.
  Future<int> start(
    List<Question> questions, {
    required bool timed,
    required DateTime startedAt,
    int? replaceUnfinishedId,
  }) => _db.mocksDao.create(
    questionIds: [for (final question in questions) question.id],
    timed: timed,
    startedAt: startedAt,
    replaceUnfinishedId: replaceUnfinishedId,
  );

  /// Persists the in-progress answers (one slot per question, null = blank).
  Future<void> saveAnswers(int id, List<int?> answers) =>
      _db.mocksDao.saveAnswers(id, answers);

  /// Persists the ids of the questions marked as doubtful.
  Future<void> saveFlagged(int id, Iterable<String> flagged) =>
      _db.mocksDao.saveFlagged(id, flagged);

  /// Closes the mock with its final [answers] and [result].
  Future<void> finish(
    int id,
    MockResult result,
    List<int?> answers,
    DateTime finishedAt,
  ) => _db.mocksDao.finish(
    id,
    answers: answers,
    correctCount: result.correct,
    passed: result.passed,
    passMark: result.passMark,
    finishedAt: finishedAt,
  );

  Future<MockRecord?> byId(int id) async {
    final row = await _db.mocksDao.byId(id);
    return row == null ? null : _toRecord(row);
  }

  /// The mock left open with the highest id (the one to resume), or null.
  Future<MockRecord?> latestUnfinished() async {
    final row = await _db.mocksDao.latestUnfinished();
    return row == null ? null : _toRecord(row);
  }

  /// [latestUnfinished], re-emitted on every change.
  Stream<MockRecord?> watchLatestUnfinished() => _db.mocksDao
      .watchLatestUnfinished()
      .map((row) => row == null ? null : _toRecord(row));

  /// Question ids of the last [limit] **finished** mocks, newest first: the
  /// `recentMocks` argument of `generateMock`.
  Future<List<List<String>>> recentQuestionIds(int limit) async {
    if (limit <= 0) return const [];
    final rows = await _db.mocksDao.recent(limit);
    return [for (final row in rows) row.questionIds];
  }

  /// The last [limit] finished mocks, newest first.
  Future<List<MockRecord>> history(int limit) async {
    if (limit <= 0) return const [];
    final rows = await _db.mocksDao.recent(limit);
    return rows.map(_toRecord).toList();
  }

  /// Number of finished mocks, re-emitted on every change.
  Stream<int> watchFinishedCount() => _db.mocksDao.watchFinishedCount();

  /// Total exams stored, including open exams.
  Future<int> startedCount() => _db.mocksDao.startedCount();

  static MockRecord _toRecord(MockRow row) => MockRecord(
    id: row.id,
    startedAt: row.startedAt,
    finishedAt: row.finishedAt,
    questionIds: row.questionIds,
    answers: row.answers,
    correct: row.correctCount,
    passed: row.passed,
    passMark: row.passMark,
    flagged: row.flagged,
    timed: row.timed,
  );
}
