import 'package:flutter/foundation.dart' show immutable;

/// Where an answer was given. Every mode feeds Fallos, SRS and mastery
/// (spec §4 P0.4: mistakes are gathered from all modes).
enum AttemptMode { practice, mock, review, srs }

/// Longest time an answer may have taken (a day): anything above or below
/// zero comes from a wrong clock and is not stored (practice) or is dropped
/// (a progress file).
const int kMaxAttemptElapsedMs = 24 * 60 * 60 * 1000;

/// One answered (or, in a mock, left blank) question.
@immutable
class Attempt {
  const Attempt({
    required this.questionId,
    required this.mode,
    required this.selected,
    required this.correct,
    required this.answeredAt,
    this.mockId,
    this.elapsedMs,
  });

  final String questionId;
  final AttemptMode mode;

  /// 0-based option, or null when a mock question was left unanswered
  /// (which counts as wrong).
  final int? selected;
  final bool correct;
  final DateTime answeredAt;
  final int? mockId;
  final int? elapsedMs;

  @override
  bool operator ==(Object other) =>
      other is Attempt &&
      other.questionId == questionId &&
      other.mode == mode &&
      other.selected == selected &&
      other.correct == correct &&
      other.answeredAt == answeredAt &&
      other.mockId == mockId &&
      other.elapsedMs == elapsedMs;

  @override
  int get hashCode => Object.hash(
    questionId,
    mode,
    selected,
    correct,
    answeredAt,
    mockId,
    elapsedMs,
  );

  @override
  String toString() =>
      'Attempt($questionId, ${mode.name}, $selected, correct: $correct)';
}
