import 'package:drift/drift.dart';

import '../../../features/content/domain/question.dart';
import '../app_database.dart';
import '../tables.dart';

part 'questions_dao.g.dart';

@DriftAccessor(tables: [Questions])
class QuestionsDao extends DatabaseAccessor<AppDatabase>
    with _$QuestionsDaoMixin {
  QuestionsDao(super.db);

  /// Numeric part of the id (`t1-002` -> 2), so `t1-002` sorts before
  /// `t1-010` even if the zero padding ever changes.
  static final _numericId = CustomExpression<int>(
    "CAST(substr(questions.id, instr(questions.id, '-') + 1) AS INTEGER)",
  );

  /// Bank order: tema, numeric id, then the raw id as a tie-break.
  static List<OrderingTerm Function(Questions)> get _bankOrder => [
    (t) => OrderingTerm.asc(t.tema),
    (t) => OrderingTerm.asc(_numericId),
    (t) => OrderingTerm.asc(t.id),
  ];

  /// Inserts new questions and updates existing ones by id (a previously
  /// retired question that is back in the bank is re-activated). Returns how
  /// many ids were new / already present.
  Future<({int inserted, int updated})> upsertAll(List<Question> items) async {
    if (items.isEmpty) return (inserted: 0, updated: 0);
    return transaction(() async {
      final existing =
          (await (selectOnly(questions)..addColumns([questions.id]))
                  .map((r) => r.read(questions.id)!)
                  .get())
              .toSet();
      final updated = items.where((q) => existing.contains(q.id)).length;
      await batch((b) {
        b.insertAllOnConflictUpdate(questions, [
          for (final q in items) _toCompanion(q),
        ]);
      });
      return (inserted: items.length - updated, updated: updated);
    });
  }

  /// Flags as retired every question whose id is not in [currentIds]; never
  /// deletes. Returns how many were newly retired.
  Future<int> markRetiredExcept(Set<String> currentIds) {
    final stmt = update(questions)
      ..where((t) => t.id.isNotIn(currentIds) & t.retired.equals(false));
    return stmt.write(const QuestionsCompanion(retired: Value(true)));
  }

  /// Non-retired questions: by tema, then numeric id order.
  Future<List<Question>> allActive() async {
    final rows =
        await (select(questions)
              ..where((t) => t.retired.equals(false))
              ..orderBy(_bankOrder))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// Non-retired questions of one tema, in id order.
  Future<List<Question>> byTema(int tema) async {
    final rows =
        await (select(questions)
              ..where((t) => t.retired.equals(false) & t.tema.equals(tema))
              ..orderBy(_bankOrder))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// The questions with these ids **in the requested order**. Retired ones
  /// are included (history and past mocks still show them); unknown ids are
  /// skipped.
  Future<List<Question>> byIds(Iterable<String> ids) async {
    final wanted = ids.toList();
    if (wanted.isEmpty) return const [];
    final rows = await (select(
      questions,
    )..where((t) => t.id.isIn(wanted))).get();
    final byId = {for (final r in rows) r.id: _toDomain(r)};
    return [
      for (final id in wanted)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// Non-retired question count per tema (tema -> count).
  Future<Map<int, int>> countByTema() async {
    final count = questions.id.count();
    final rows =
        await (selectOnly(questions)
              ..addColumns([questions.tema, count])
              ..where(questions.retired.equals(false))
              ..groupBy([questions.tema])
              ..orderBy([OrderingTerm.asc(questions.tema)]))
            .get();
    return {for (final r in rows) r.read(questions.tema)!: r.read(count)!};
  }

  static QuestionsCompanion _toCompanion(Question q) => QuestionsCompanion(
    id: Value(q.id),
    tema: Value(q.tema),
    section: Value(q.section),
    stem: Value(q.stem),
    options: Value(q.options),
    answer: Value(q.answer),
    explanation: Value(q.explanation),
    article: Value(q.article),
    notice: Value(q.notice),
    flags: Value(q.flags),
    edition: Value(q.edition),
    reviewed: Value(q.reviewed),
    retired: const Value(false),
  );

  static Question _toDomain(QuestionRow r) => Question(
    id: r.id,
    tema: r.tema,
    section: r.section,
    stem: r.stem,
    options: r.options,
    answer: r.answer,
    explanation: r.explanation,
    article: r.article,
    notice: r.notice,
    flags: r.flags,
    edition: r.edition,
    reviewed: r.reviewed,
  );
}
