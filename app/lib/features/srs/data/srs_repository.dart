import '../../../core/database/app_database.dart';
import '../../../core/format/civil_day.dart';
import '../domain/srs_card.dart';

/// Leitner cards (`srs_state`) as domain [SrsCard]s.
class SrsRepository {
  SrsRepository(this._db);

  final AppDatabase _db;

  /// Every card, ordered by question id.
  Future<List<SrsCard>> all() async {
    final rows = await _db.srsDao.all();
    return rows.map(cardFromRow).toList();
  }

  /// [all], re-emitted on every change.
  Stream<List<SrsCard>> watchAll() =>
      _db.srsDao.watchAll().map((rows) => rows.map(cardFromRow).toList());

  /// The card of [questionId], or null when it was never answered.
  Future<SrsCard?> get(String questionId) async {
    final row = await _db.srsDao.get(questionId);
    return row == null ? null : cardFromRow(row);
  }

  /// Inserts or replaces the card of `card.questionId`.
  Future<void> upsert(SrsCard card) => _db.srsDao.upsert(rowFromCard(card));

  /// Row -> domain. A row without `lastAnsweredAt` (never written by the app)
  /// falls back to its due date. A `dueDay` that is not a date is ignored:
  /// the card falls back to its `dueAt`.
  static SrsCard cardFromRow(SrsStateRow row) => SrsCard(
    questionId: row.questionId,
    box: row.box,
    dueAt: row.dueAt,
    reps: row.reps,
    lapses: row.lapses,
    lastAnsweredAt: row.lastAnsweredAt ?? row.dueAt,
    dueDay: parseIsoDay(row.dueDay) == null ? null : row.dueDay,
  );

  static SrsStateRow rowFromCard(SrsCard card) => SrsStateRow(
    questionId: card.questionId,
    box: card.box,
    dueAt: card.dueAt,
    reps: card.reps,
    lapses: card.lapses,
    lastAnsweredAt: card.lastAnsweredAt,
    dueDay: card.dueDay,
  );
}
