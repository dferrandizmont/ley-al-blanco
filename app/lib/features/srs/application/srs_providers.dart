import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../content/application/content_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../quiz/application/quiz_providers.dart';
import '../../quiz/domain/attempt.dart';
import '../data/srs_repository.dart';
import '../domain/daily_queue.dart';
import '../domain/srs_card.dart';
import '../domain/srs_review.dart';

final srsRepositoryProvider = Provider<SrsRepository>(
  (ref) => SrsRepository(ref.watch(appDatabaseProvider)),
);

/// Every Leitner card, re-emitted on each change.
final srsCardsProvider = StreamProvider<List<SrsCard>>(
  (ref) => ref.watch(srsRepositoryProvider).watchAll(),
);

/// How many questions had their **first ever attempt** on the local calendar
/// day of [now] (only ids in [activeIds]). This is what counts against the
/// daily quota of new questions.
int newIntroducedToday({
  required Iterable<Attempt> attempts,
  required Set<String> activeIds,
  required DateTime now,
}) {
  final firstAnswer = <String, DateTime>{};
  for (final attempt in attempts) {
    if (!activeIds.contains(attempt.questionId)) continue;
    final known = firstAnswer[attempt.questionId];
    if (known == null || attempt.answeredAt.isBefore(known)) {
      firstAnswer[attempt.questionId] = attempt.answeredAt;
    }
  }
  final today = startOfLocalDay(now);
  return firstAnswer.values
      .where((answeredAt) => startOfLocalDay(answeredAt) == today)
      .length;
}

/// Ids for "Continuar" today: due cards first, then new questions from the
/// least-mastered temas, capped by the daily quota (plan 2.6).
///
/// Computed against `clockProvider()` at build time; it is not re-evaluated
/// when midnight passes, so the UI should invalidate it when the app resumes.
final dailyQueueProvider = FutureProvider<List<String>>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final attempts = await ref.watch(attemptsProvider.future);
  final cards = await ref.watch(srsCardsProvider.future);
  final temaMastery = await ref.watch(temaMasteryProvider.future);
  // A tema mean is a float sum / count: temas at the same prior (1/3) differ
  // in the last bits (68 x 1/3 / 68 != 70 x 1/3 / 70), which would turn a
  // genuine tie into an arbitrary order. Round so ties resolve by tema number.
  final masteryByTema = {
    for (final entry in temaMastery.entries)
      entry.key: (entry.value * 1e9).roundToDouble() / 1e9,
  };
  final now = ref.watch(clockProvider)();
  return dailyQueue(
    cards: cards,
    questions: questions,
    now: now,
    masteryByTema: masteryByTema,
    newIntroducedToday: newIntroducedToday(
      attempts: attempts,
      activeIds: {for (final question in questions) question.id},
      now: now,
    ),
  );
});
