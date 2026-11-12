import 'package:flutter/foundation.dart' show immutable;

import '../../../core/format/civil_day.dart';
import '../../content/domain/question.dart';

export '../../../core/format/civil_day.dart'
    show
        addCivilDays,
        civilDay,
        daysBetween,
        deviceOffsetMinutes,
        isoDayOf,
        parseIsoDay,
        startOfCivilDay;

/// "Pregunta del día": one question a day, the same for the whole day, and the
/// streak of consecutive days on which the user answered it.
///
/// Days are **local calendar days** (the device's zone, Europe/Madrid for the
/// intended users), like the rest of the app (`startOfLocalDay` in the daily
/// queue): the question and the streak change at local midnight.
///
/// Travelling does not break the streak: the day of the last answer is kept
/// with the instant it was made in and the offset of the zone at that
/// moment, so a change of zone is told apart from a day without study.

/// ISO 8601 date (`2026-10-15`) of the local calendar day of [moment].
String isoDay(DateTime moment) =>
    isoDayOf(civilDay(moment, deviceOffsetMinutes(moment)));

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
  const DailyProgress({
    this.lastDay,
    this.streak = 0,
    this.lastQuestionId,
    this.lastAt,
    this.lastOffsetMinutes,
  });

  /// Nothing answered yet.
  static const DailyProgress none = DailyProgress();

  /// [isoDay] of the last day the question was answered; null = never.
  final String? lastDay;

  /// Consecutive days up to and including [lastDay].
  final int streak;

  /// The question answered on [lastDay].
  final String? lastQuestionId;

  /// The instant (UTC) of the last credited answer. Null in the progress
  /// written before this field existed: then a change of zone cannot be told
  /// apart from a day without study.
  final DateTime? lastAt;

  /// The offset of the device's zone (in minutes) when the last answer was
  /// credited. Null in the progress written before this field existed.
  final int? lastOffsetMinutes;

  /// Whether the question of the day of [now] was already answered.
  ///
  /// [offsetMinutes] is the offset of the device's zone; the default is the
  /// zone of the process. Travelling west can leave the calendar day behind
  /// the day of the last answer: that answer still counts as the answer of
  /// the day (a day is never credited twice), unless the clock was moved back
  /// by hand more than 48 hours.
  bool answeredOn(DateTime now, {int? offsetMinutes}) {
    final last = parseIsoDay(lastDay);
    if (last == null) return false;
    final offset = offsetMinutes ?? deviceOffsetMinutes(now);
    final gap = daysBetween(last, civilDay(now, offset));
    if (gap == 0) return true;
    if (gap > 0) return false;
    final at = lastAt;
    if (at == null) return gap == -1;
    return now.toUtc().difference(at.toUtc()).abs() <=
        const Duration(hours: 48);
  }

  /// The streak to show on the day of [now]: the stored one while it is
  /// alive, 0 once a day was skipped.
  ///
  /// A change of zone does not break it: the day of the last answer is read
  /// in the offset it was made in, and a trip that jumps a calendar day is
  /// forgiven when the change of offset explains it.
  int streakOn(DateTime now, {int? offsetMinutes}) {
    final last = parseIsoDay(lastDay);
    if (last == null || streak <= 0) return 0;
    final offset = offsetMinutes ?? deviceOffsetMinutes(now);
    if (answeredOn(now, offsetMinutes: offset)) return streak;
    final gap = daysBetween(last, civilDay(now, offset));
    if (gap == 1) return streak;
    final lastOffset = lastOffsetMinutes;
    if (lastOffset == null || offset == lastOffset) return 0;
    // The zone changed: read the day of the last answer in the old zone.
    final gapInOldZone = daysBetween(last, civilDay(now, lastOffset));
    if (gapInOldZone == 0 || gapInOldZone == 1) return streak;
    // A long flight east: the calendar jumped a day, but not 48 hours.
    final at = lastAt;
    if (gap == 2 &&
        (offset - lastOffset).abs() >= 120 &&
        at != null &&
        now.toUtc().difference(at.toUtc()) <= const Duration(hours: 48)) {
      return streak;
    }
    return 0;
  }

  /// The state after answering [questionId] on [now]: the same day again
  /// changes nothing; the day after the last answer adds one; anything else (a
  /// skipped day, a clock moved back more than 48 hours, no previous answer)
  /// starts again at 1.
  DailyProgress afterAnswer(
    DateTime now,
    String questionId, {
    int? offsetMinutes,
  }) {
    final offset = offsetMinutes ?? deviceOffsetMinutes(now);
    if (answeredOn(now, offsetMinutes: offset)) return this;
    return DailyProgress(
      lastDay: isoDayOf(civilDay(now, offset)),
      streak: streakOn(now, offsetMinutes: offset) + 1,
      lastQuestionId: questionId,
      lastAt: now.toUtc(),
      lastOffsetMinutes: offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyProgress &&
      other.lastDay == lastDay &&
      other.streak == streak &&
      other.lastQuestionId == lastQuestionId &&
      other.lastAt == lastAt &&
      other.lastOffsetMinutes == lastOffsetMinutes;

  @override
  int get hashCode =>
      Object.hash(lastDay, streak, lastQuestionId, lastAt, lastOffsetMinutes);

  @override
  String toString() =>
      'DailyProgress($lastDay, streak: $streak, at: $lastAt, '
      'offset: $lastOffsetMinutes)';
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
