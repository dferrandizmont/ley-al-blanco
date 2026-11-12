import '../../../core/format/civil_day.dart';
import '../../content/domain/question.dart';
import 'srs_card.dart';
import 'srs_review.dart';

/// Default cap of new questions introduced per day (plan 2.6).
const kDefaultNewPerDay = 15;

/// The "Continuar" queue of question ids for today (plan 2.6).
///
/// 1. **Due cards** first: those whose due day is today or earlier (a card
///    with a `dueDay`), or those with `dueAt` before the start of tomorrow
///    (local calendar) when they have none, i.e. due any time today or
///    overdue. Ordered by the day they are due, then `dueAt` ascending, then
///    box ascending (weakest first), then id.
/// 2. Then **new questions** (no card), at most
///    `max(0, newPerDay - newIntroducedToday)`, prioritising the temas with
///    the least mastery: ordered by [masteryByTema] ascending (a tema missing
///    from the map counts as 0, i.e. unknown comes first), then tema, then
///    the order in [questions].
///
/// Finally, due cards answered in the last 10 minutes move behind the new
/// questions, preserving their relative order and the selected set.
///
/// Cards whose id is not in [questions] (retired questions) are ignored, as
/// are retired ids in general. [now] is injected; nothing reads the clock.
/// [offsetMinutes] is the offset of the device's zone (the default: the zone
/// of the process): it decides the civil day of today and the day a card
/// without a `dueDay` falls on.
List<String> dailyQueue({
  required Iterable<SrsCard> cards,
  required List<Question> questions,
  required DateTime now,
  required Map<int, double> masteryByTema,
  int newPerDay = kDefaultNewPerDay,
  int newIntroducedToday = 0,
  int? offsetMinutes,
}) {
  final cardList = cards.toList();
  final byId = {for (final q in questions) q.id: q};
  final offset = offsetMinutes ?? deviceOffsetMinutes(now);
  final today = civilDay(now, offset);
  final startOfTomorrow = offsetMinutes == null
      ? startOfLocalDay(now, plusDays: 1)
      : startOfCivilDay(addCivilDays(today, 1), offset);
  final todayIso = isoDayOf(today);

  bool isDue(SrsCard card) {
    final dueDay = card.dueDay;
    if (dueDay != null) return dueDay.compareTo(todayIso) <= 0;
    return card.dueAt.isBefore(startOfTomorrow);
  }

  /// The day the card falls on: its own `dueDay`, or the local civil day of
  /// its `dueAt` (the cards written before the field existed). The device
  /// zone at `dueAt` on purpose: that `dueAt` is a local midnight.
  String dueDayOf(SrsCard card) =>
      card.dueDay ??
      isoDayOf(civilDay(card.dueAt, deviceOffsetMinutes(card.dueAt)));

  final due =
      cardList.where((c) => byId.containsKey(c.questionId) && isDue(c)).toList()
        ..sort((a, b) {
          final byDay = dueDayOf(a).compareTo(dueDayOf(b));
          if (byDay != 0) return byDay;
          final byDue = a.dueAt.compareTo(b.dueAt);
          if (byDue != 0) return byDue;
          final byBox = a.box.compareTo(b.box);
          if (byBox != 0) return byBox;
          return a.questionId.compareTo(b.questionId);
        });

  final withCard = {for (final c in cardList) c.questionId};
  final newSlots = newPerDay - newIntroducedToday;
  final fresh = <(int, Question)>[];
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    if (withCard.contains(question.id)) continue;
    fresh.add((i, question));
  }
  fresh.sort((a, b) {
    final byMastery = (masteryByTema[a.$2.tema] ?? 0.0).compareTo(
      masteryByTema[b.$2.tema] ?? 0.0,
    );
    if (byMastery != 0) return byMastery;
    final byTema = a.$2.tema.compareTo(b.$2.tema);
    return byTema != 0 ? byTema : a.$1.compareTo(b.$1);
  });

  final recent = {
    for (final card in due)
      if (!card.lastAnsweredAt.isAfter(now) &&
          now.difference(card.lastAnsweredAt) < const Duration(minutes: 10))
        card.questionId,
  };
  return [
    for (final card in due)
      if (!recent.contains(card.questionId)) card.questionId,
    if (newSlots > 0)
      for (final entry in fresh.take(newSlots)) entry.$2.id,
    for (final card in due)
      if (recent.contains(card.questionId)) card.questionId,
  ];
}
