import 'package:flutter/foundation.dart' show immutable;

import '../../content/domain/question.dart';

/// "Pregunta del día": one question a day, the same for the whole day, and the
/// streak of consecutive days on which the user answered it.
///
/// Days are **local calendar days** (the device's zone, Europe/Madrid for the
/// intended users), like the rest of the app (`startOfLocalDay` in the daily
/// queue): the question and the streak change at local midnight.

/// ISO 8601 date (`2026-10-15`) of the local calendar day of [moment].
String isoDay(DateTime moment) {
  final local = moment.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}';
}

final RegExp _isoDayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// The calendar day of an [isoDay] string (a UTC midnight, so differences are
/// whole days even across a daylight-saving change), or null when [raw] is
/// not a valid date.
DateTime? parseIsoDay(String? raw) {
  final match = raw == null ? null : _isoDayPattern.firstMatch(raw);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  // `DateTime.utc(2026, 2, 31)` rolls over to March: reject it.
  if (date.month != month || date.day != day) return null;
  return date;
}

/// Whole days from the day [from] to the day [to] (negative when [to] is
/// earlier).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// FNV-1a over the UTF-16 code units of [text]: a stable 32-bit hash that does
/// not depend on the platform or the Dart version (`String.hashCode` does).
int _fnv1a(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// The question of the day among [eligible] (bank order): a deterministic
/// function of the ISO date of [day] and of the list, so every launch of the
/// same day shows the same question. Null when there is nothing to pick from.
Question? pickDailyQuestion(List<Question> eligible, DateTime day) {
  if (eligible.isEmpty) return null;
  return eligible[_fnv1a(isoDay(day)) % eligible.length];
}

/// What is stored about the daily question: the last day it was answered, the
/// streak that day ended with and which question it was.
@immutable
class DailyProgress {
  const DailyProgress({this.lastDay, this.streak = 0, this.lastQuestionId});

  /// Nothing answered yet.
  static const DailyProgress none = DailyProgress();

  /// [isoDay] of the last day the question was answered; null = never.
  final String? lastDay;

  /// Consecutive days up to and including [lastDay].
  final int streak;

  /// The question answered on [lastDay].
  final String? lastQuestionId;

  /// Whether the question of [today] was already answered.
  bool answeredOn(DateTime today) => lastDay == isoDay(today);

  /// The streak to show on [today]: the stored one while it is alive (the last
  /// answer was today or yesterday), 0 once a day was skipped.
  int streakOn(DateTime today) {
    final last = parseIsoDay(lastDay);
    if (last == null || streak <= 0) return 0;
    final gap = daysBetween(last, today);
    return gap == 0 || gap == 1 ? streak : 0;
  }

  /// The state after answering [questionId] on [now]: the same day again
  /// changes nothing; the day after the last answer adds one; anything else (a
  /// skipped day, a clock moved back, no previous answer) starts again at 1.
  DailyProgress afterAnswer(DateTime now, String questionId) {
    if (answeredOn(now)) return this;
    return DailyProgress(
      lastDay: isoDay(now),
      streak: streakOn(now) + 1,
      lastQuestionId: questionId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyProgress &&
      other.lastDay == lastDay &&
      other.streak == streak &&
      other.lastQuestionId == lastQuestionId;

  @override
  int get hashCode => Object.hash(lastDay, streak, lastQuestionId);

  @override
  String toString() => 'DailyProgress($lastDay, streak: $streak)';
}

/// Today's state for Inicio.
@immutable
class DailyStatus {
  const DailyStatus({
    required this.question,
    required this.answeredToday,
    required this.streak,
  });

  /// Today's question; null when the bank has nothing to offer.
  final Question? question;
  final bool answeredToday;

  /// The streak to show (0 once a day was skipped).
  final int streak;
}
