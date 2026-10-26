import 'srs_card.dart';

/// Local midnight at the start of the calendar day of [moment], plus
/// [days] calendar days.
///
/// Uses calendar arithmetic (`DateTime(y, m, d + n)`), not a `Duration`, so a
/// daylight-saving change (25 h or 23 h days) never shifts the result off
/// midnight. A UTC [moment] is converted to local time first.
DateTime startOfLocalDay(DateTime moment, {int plusDays = 0}) {
  final local = moment.toLocal();
  return DateTime(local.year, local.month, local.day + plusDays);
}

/// Applies one answer to a Leitner card (plan 2.6) and returns the new card.
///
/// * No card yet: correct -> box 2, wrong -> box 1.
/// * Existing card: correct -> `min(box + 1, 5)`; wrong -> box 1 and
///   `lapses + 1`.
/// * Always: `reps + 1`, `lastAnsweredAt = now`, and
///   `dueAt = start of the local day of now + kLeitnerIntervalsDays[box - 1]`
///   calendar days. Box 1 is therefore due again today.
///
/// Throws [ArgumentError] when [card] belongs to another question.
SrsCard review(
  SrsCard? card, {
  required String questionId,
  required bool correct,
  required DateTime now,
}) {
  if (card != null && card.questionId != questionId) {
    throw ArgumentError.value(
      card.questionId,
      'card',
      'belongs to another question than $questionId',
    );
  }
  final int box;
  if (correct) {
    box = card == null ? 2 : (card.box + 1).clamp(1, kMaxBox);
  } else {
    box = 1;
  }
  return SrsCard(
    questionId: questionId,
    box: box,
    dueAt: startOfLocalDay(now, plusDays: kLeitnerIntervalsDays[box - 1]),
    reps: (card?.reps ?? 0) + 1,
    lapses: (card?.lapses ?? 0) + (!correct && card != null ? 1 : 0),
    lastAnsweredAt: now,
  );
}
