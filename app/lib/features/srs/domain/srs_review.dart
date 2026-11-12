import '../../../core/format/civil_day.dart';
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
/// * Always: `reps + 1`, `lastAnsweredAt = now`,
///   `dueAt = start of the local day of now + kLeitnerIntervalsDays[box - 1]`
///   calendar days and `dueDay = the same day in ISO 8601`. Box 1 is
///   therefore due again today.
///
/// [offsetMinutes] is the offset of the device's zone when the answer was
/// given (the default: the zone of the process). It only decides the civil
/// day of [dueDay]; [dueAt] keeps being the local midnight of that day, as
/// the older versions of the app wrote it.
///
/// Throws [ArgumentError] when [card] belongs to another question.
SrsCard review(
  SrsCard? card, {
  required String questionId,
  required bool correct,
  required DateTime now,
  int? offsetMinutes,
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
  final offset = offsetMinutes ?? deviceOffsetMinutes(now);
  final interval = kLeitnerIntervalsDays[box - 1];
  return SrsCard(
    questionId: questionId,
    box: box,
    dueAt: startOfLocalDay(now, plusDays: interval),
    dueDay: isoDayOf(addCivilDays(civilDay(now, offset), interval)),
    reps: (card?.reps ?? 0) + 1,
    lapses: (card?.lapses ?? 0) + (!correct && card != null ? 1 : 0),
    lastAnsweredAt: now,
  );
}
