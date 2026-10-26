import 'package:drift/drift.dart';

import '../../../features/quiz/domain/attempt.dart';
import '../app_database.dart';
import '../tables.dart';

part 'attempts_dao.g.dart';

@DriftAccessor(tables: [Attempts])
class AttemptsDao extends DatabaseAccessor<AppDatabase>
    with _$AttemptsDaoMixin {
  AttemptsDao(super.db);

  /// Chronological; ties (same instant) fall back to insertion order.
  static List<OrderingTerm Function(Attempts)> get _chronological => [
    (t) => OrderingTerm.asc(t.answeredAt),
    (t) => OrderingTerm.asc(t.id),
  ];

  Future<void> insert(Attempt attempt) async {
    await into(attempts).insert(_toCompanion(attempt));
  }

  /// Inserts all [items] in one transaction (a finished mock records 20).
  Future<void> insertAll(List<Attempt> items) async {
    if (items.isEmpty) return;
    await transaction(() async {
      await batch((b) {
        b.insertAll(attempts, [for (final a in items) _toCompanion(a)]);
      });
    });
  }

  /// Every attempt, oldest first.
  Future<List<Attempt>> all() async {
    final rows = await (select(attempts)..orderBy(_chronological)).get();
    return rows.map(_toDomain).toList();
  }

  /// The attempts on one question, oldest first.
  Future<List<Attempt>> forQuestion(String questionId) async {
    final rows =
        await (select(attempts)
              ..where((t) => t.questionId.equals(questionId))
              ..orderBy(_chronological))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// [all], re-emitted on every change.
  Stream<List<Attempt>> watchAll() =>
      (select(attempts)..orderBy(_chronological)).watch().map(
        (rows) => rows.map(_toDomain).toList(),
      );

  static AttemptsCompanion _toCompanion(Attempt a) => AttemptsCompanion.insert(
    questionId: a.questionId,
    mode: a.mode,
    selected: Value(a.selected),
    correct: a.correct,
    answeredAt: a.answeredAt,
    mockId: Value(a.mockId),
    elapsedMs: Value(a.elapsedMs),
  );

  static Attempt _toDomain(AttemptRow r) => Attempt(
    questionId: r.questionId,
    mode: r.mode,
    selected: r.selected,
    correct: r.correct,
    answeredAt: r.answeredAt,
    mockId: r.mockId,
    elapsedMs: r.elapsedMs,
  );
}
