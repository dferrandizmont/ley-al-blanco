import '../../../core/database/app_database.dart';
import '../../srs/data/srs_repository.dart';
import '../../srs/domain/srs_card.dart';
import '../../srs/domain/srs_review.dart';
import '../data/attempt_repository.dart';
import '../domain/attempt.dart';

/// Write side of studying: the one place every mode (practice, review, srs,
/// mock) records what the user answered, so Fallos, SRS and mastery all see
/// the same history.
class StudyService {
  StudyService({
    required this._db,
    required this._attempts,
    required this._srs,
  });

  final AppDatabase _db;
  final AttemptRepository _attempts;
  final SrsRepository _srs;

  /// Stores [attempts] and moves each question's Leitner card, in **one
  /// transaction** (either everything is written or nothing is).
  ///
  /// Attempts are applied in `answeredAt` order (equal timestamps keep their
  /// input order). A mock question left blank is an attempt with
  /// `correct: false`, so it counts as a miss for SRS too. Safe to call inside
  /// an outer transaction (Drift nests it), which is how `finishMock` makes
  /// the score and the attempts atomic.
  Future<void> recordAnswers(List<Attempt> attempts) async {
    if (attempts.isEmpty) return;
    final ordered = _byAnsweredAt(attempts);
    await _db.transaction(() async {
      await _attempts.addAll(ordered);

      final cards = <String, SrsCard>{};
      for (final attempt in ordered) {
        final id = attempt.questionId;
        final current = cards.containsKey(id) ? cards[id] : await _srs.get(id);
        cards[id] = review(
          current,
          questionId: id,
          correct: attempt.correct,
          now: attempt.answeredAt,
        );
      }
      for (final card in cards.values) {
        await _srs.upsert(card);
      }
    });
  }

  /// Sorted copy by `answeredAt`; `List.sort` is not stable, so the input
  /// position breaks ties.
  static List<Attempt> _byAnsweredAt(List<Attempt> attempts) {
    final indexed = [for (var i = 0; i < attempts.length; i++) (i, attempts[i])]
      ..sort((a, b) {
        final byDate = a.$2.answeredAt.compareTo(b.$2.answeredAt);
        return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
      });
    return [for (final (_, attempt) in indexed) attempt];
  }
}
