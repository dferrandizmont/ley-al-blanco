import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'mocks_dao.g.dart';

@DriftAccessor(tables: [Mocks])
class MocksDao extends DatabaseAccessor<AppDatabase> with _$MocksDaoMixin {
  MocksDao(super.db);

  /// Stores a new exam, optionally replacing the open exam the user confirmed.
  Future<int> create({
    required List<String> questionIds,
    required bool timed,
    required DateTime startedAt,
    int? replaceUnfinishedId,
  }) => transaction(() async {
    if (replaceUnfinishedId != null) await _deleteOpen([replaceUnfinishedId]);
    return into(mocks).insert(
      MocksCompanion.insert(
        startedAt: startedAt,
        questionIds: questionIds,
        answers: List<int?>.filled(questionIds.length, null),
        timed: timed,
      ),
    );
  });

  /// Persists the in-progress answers (so an interrupted mock can resume).
  /// [answers] has one entry per question, null = blank.
  Future<void> saveAnswers(int id, List<int?> answers) async {
    await _checkLength(id, answers);
    await (update(mocks)..where((t) => t.id.equals(id))).write(
      MocksCompanion(answers: Value(answers)),
    );
  }

  /// Persists the ids of the questions marked as doubtful. Only ids of the
  /// mock's own questions are kept (in exam order), so a stale or foreign id
  /// can never end up stored.
  Future<void> saveFlagged(int id, Iterable<String> flagged) async {
    final mock = await byId(id);
    if (mock == null) throw ArgumentError.value(id, 'id', 'No such mock');
    final wanted = flagged.toSet();
    await (update(mocks)..where((t) => t.id.equals(id))).write(
      MocksCompanion(
        flagged: Value([
          for (final questionId in mock.questionIds)
            if (wanted.contains(questionId)) questionId,
        ]),
      ),
    );
  }

  /// Closes a mock with its final answers and score. [passMark] is the one
  /// that decided [passed]; kept so the verdict can be explained later even if
  /// the exam config changes.
  Future<void> finish(
    int id, {
    required List<int?> answers,
    required int correctCount,
    required bool passed,
    required DateTime finishedAt,
    int? passMark,
  }) {
    return transaction(() async {
      await _checkLength(id, answers);
      await (update(mocks)..where((t) => t.id.equals(id))).write(
        MocksCompanion(
          answers: Value(answers),
          correctCount: Value(correctCount),
          passed: Value(passed),
          passMark: Value(passMark),
          finishedAt: Value(finishedAt),
        ),
      );
    });
  }

  /// Finished mocks, newest first.
  Future<List<MockRow>> recent(int limit) =>
      (select(mocks)
            ..where((t) => t.finishedAt.isNotNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.finishedAt),
              (t) => OrderingTerm.desc(t.id),
            ])
            ..limit(limit))
          .get();

  /// The mock left open (never handed in) with the highest id, or null. The
  /// app keeps at most one open (see [create]), this is the one to resume.
  Future<MockRow?> latestUnfinished() =>
      _latestUnfinishedQuery().getSingleOrNull();

  /// [latestUnfinished], re-emitted on every change.
  Stream<MockRow?> watchLatestUnfinished() =>
      _latestUnfinishedQuery().watchSingleOrNull();

  SimpleSelectStatement<$MocksTable, MockRow> _latestUnfinishedQuery() =>
      select(mocks)
        ..where((t) => t.finishedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.id)])
        ..limit(1);

  /// Deletes every mock that was never handed in, with the attempts that point
  /// at them (an imported file could leave some). Returns how many mocks.
  Future<int> deleteUnfinished() => transaction(() async {
    final open = await (select(
      mocks,
    )..where((t) => t.finishedAt.isNull())).get();
    return _deleteOpen([for (final mock in open) mock.id]);
  });

  /// Deletes the open mocks among [ids] and the attempts that point at them.
  /// A mock handed in is never touched. Returns how many mocks went.
  Future<int> _deleteOpen(List<int> ids) async {
    if (ids.isEmpty) return 0;
    return transaction(() async {
      final open = await (select(
        mocks,
      )..where((t) => t.id.isIn(ids) & t.finishedAt.isNull())).get();
      final openIds = [for (final mock in open) mock.id];
      if (openIds.isEmpty) return 0;
      await (delete(db.attempts)..where((t) => t.mockId.isIn(openIds))).go();
      return (delete(mocks)..where((t) => t.id.isIn(openIds))).go();
    });
  }

  /// Number of finished mocks, re-emitted on every change.
  Stream<int> watchFinishedCount() {
    final count = mocks.id.count();
    return (selectOnly(mocks)
          ..addColumns([count])
          ..where(mocks.finishedAt.isNotNull()))
        .map((r) => r.read(count)!)
        .watchSingle();
  }

  /// Total exams stored, including open exams.
  Future<int> startedCount() async {
    final count = mocks.id.count();
    final row = await (selectOnly(mocks)..addColumns([count])).getSingle();
    return row.read(count)!;
  }

  Future<MockRow?> byId(int id) =>
      (select(mocks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> _checkLength(int id, List<int?> answers) async {
    final mock = await byId(id);
    if (mock == null) throw ArgumentError.value(id, 'id', 'No such mock');
    if (mock.questionIds.length != answers.length) {
      throw ArgumentError.value(
        answers.length,
        'answers',
        'Expected ${mock.questionIds.length} answers',
      );
    }
  }
}
