import 'package:flutter/foundation.dart' show immutable;

import '../../quiz/domain/attempt.dart';

/// A question currently in the Fallos list (plan 2.5).
@immutable
class MistakeEntry {
  const MistakeEntry({
    required this.questionId,
    required this.lastWrongAt,
    required this.wrongCount,
    required this.currentStreak,
  });

  final String questionId;

  /// When the question was last answered wrongly (any mode).
  final DateTime lastWrongAt;

  /// How many wrong attempts the question has in total.
  final int wrongCount;

  /// Consecutive correct attempts since the last wrong one (less than the
  /// required streak, or the question would not be here).
  final int currentStreak;

  @override
  bool operator ==(Object other) =>
      other is MistakeEntry &&
      other.questionId == questionId &&
      other.lastWrongAt == lastWrongAt &&
      other.wrongCount == wrongCount &&
      other.currentStreak == currentStreak;

  @override
  int get hashCode =>
      Object.hash(questionId, lastWrongAt, wrongCount, currentStreak);

  @override
  String toString() =>
      'MistakeEntry($questionId, wrong: $wrongCount, streak: $currentStreak)';
}

/// The Fallos list (plan 2.5): questions with at least one wrong attempt whose
/// run of consecutive correct attempts after the **last** wrong one is still
/// shorter than [requiredStreak] (default 2). Attempts of every mode count,
/// and a mock question left blank is a wrong attempt.
///
/// [attempts] may come in any order: they are sorted by `answeredAt` (equal
/// timestamps keep their input order). The result is sorted by `lastWrongAt`,
/// newest first (ties by question id).
///
/// Pass [tema] to keep only that tema; [temaById] (question id -> tema) is
/// then required and questions missing from it are left out.
///
/// Throws [ArgumentError] when [requiredStreak] < 1 or [tema] is given without
/// [temaById].
List<MistakeEntry> mistakes(
  Iterable<Attempt> attempts, {
  int requiredStreak = 2,
  Map<String, int>? temaById,
  int? tema,
}) {
  if (requiredStreak < 1) {
    throw ArgumentError.value(requiredStreak, 'requiredStreak', 'must be >= 1');
  }
  if (tema != null && temaById == null) {
    throw ArgumentError.notNull('temaById');
  }

  final byQuestion = <String, List<(int, Attempt)>>{};
  var order = 0;
  for (final attempt in attempts) {
    byQuestion.putIfAbsent(attempt.questionId, () => []).add((
      order++,
      attempt,
    ));
  }

  final entries = <MistakeEntry>[];
  for (final MapEntry(key: questionId, value: history) in byQuestion.entries) {
    if (tema != null && temaById![questionId] != tema) continue;
    final entry = _entryFor(questionId, history, requiredStreak);
    if (entry != null) entries.add(entry);
  }
  entries.sort((a, b) {
    final byDate = b.lastWrongAt.compareTo(a.lastWrongAt);
    return byDate != 0 ? byDate : a.questionId.compareTo(b.questionId);
  });
  return entries;
}

MistakeEntry? _entryFor(
  String questionId,
  List<(int, Attempt)> history,
  int requiredStreak,
) {
  history.sort((a, b) {
    final byDate = a.$2.answeredAt.compareTo(b.$2.answeredAt);
    return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
  });
  DateTime? lastWrongAt;
  var wrongCount = 0;
  var streak = 0;
  for (final (_, attempt) in history) {
    if (attempt.correct) {
      streak++;
    } else {
      wrongCount++;
      lastWrongAt = attempt.answeredAt;
      streak = 0;
    }
  }
  if (lastWrongAt == null || streak >= requiredStreak) return null;
  return MistakeEntry(
    questionId: questionId,
    lastWrongAt: lastWrongAt,
    wrongCount: wrongCount,
    currentStreak: streak,
  );
}
