import 'package:flutter/foundation.dart' show immutable;

/// Days until the next review per Leitner box; the index is `box - 1`
/// (plan 2.6): 0/1/3/7/16. A short horizon on purpose: candidates study for
/// 2-8 weeks, so SM-2 would not pay off.
const kLeitnerIntervalsDays = [0, 1, 3, 7, 16];

/// Highest Leitner box.
const kMaxBox = 5;

/// Spaced-repetition state of one question (table `srs_state`, plan 2.1).
@immutable
class SrsCard {
  const SrsCard({
    required this.questionId,
    required this.box,
    required this.dueAt,
    required this.reps,
    required this.lapses,
    required this.lastAnsweredAt,
  }) : assert(box >= 1 && box <= kMaxBox);

  final String questionId;

  /// Leitner box, 1..5.
  final int box;

  /// Local midnight of the day the card is due (see [review]).
  final DateTime dueAt;

  /// Times the question has been reviewed.
  final int reps;

  /// Times it was answered wrongly after having a card.
  final int lapses;
  final DateTime lastAnsweredAt;

  @override
  bool operator ==(Object other) =>
      other is SrsCard &&
      other.questionId == questionId &&
      other.box == box &&
      other.dueAt == dueAt &&
      other.reps == reps &&
      other.lapses == lapses &&
      other.lastAnsweredAt == lastAnsweredAt;

  @override
  int get hashCode =>
      Object.hash(questionId, box, dueAt, reps, lapses, lastAnsweredAt);

  @override
  String toString() => 'SrsCard($questionId, box: $box, due: $dueAt)';
}
