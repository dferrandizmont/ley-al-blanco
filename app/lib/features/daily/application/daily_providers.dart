import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/question.dart';
import '../data/daily_repository.dart';
import '../domain/daily_question.dart';

final dailyRepositoryProvider = Provider<DailyRepository>(
  (ref) => DailyRepository(ref.watch(settingsDaoProvider)),
);

/// The stored streak state, kept in memory after the first read.
class DailyProgressController extends AsyncNotifier<DailyProgress> {
  @override
  Future<DailyProgress> build() => ref.read(dailyRepositoryProvider).load();

  /// Records that [questionId] (the question of the day) was answered now.
  /// Answering again on the same day changes nothing.
  Future<void> register(String questionId) async {
    final current = await future;
    final next = current.afterAnswer(ref.read(clockProvider)(), questionId);
    if (next == current) return;
    await ref.read(dailyRepositoryProvider).save(next);
    if (ref.mounted) state = AsyncData(next);
  }
}

final dailyProgressProvider =
    AsyncNotifierProvider<DailyProgressController, DailyProgress>(
      DailyProgressController.new,
    );

/// Today's question, whether it was answered and the streak to show.
///
/// The question is stable through the day; once answered it stays the same.
/// Inicio refreshes it when the date changes.
final dailyStatusProvider = FutureProvider<DailyStatus>((ref) async {
  final questions = await ref.watch(questionsProvider.future);
  final progress = await ref.watch(dailyProgressProvider.future);
  final now = ref.watch(clockProvider)();
  final answered = progress.answeredOn(now);

  Question? question;
  if (answered) {
    for (final candidate in questions) {
      if (candidate.id == progress.lastQuestionId) question = candidate;
    }
  }
  question ??= pickDailyQuestion(questions, now);
  return DailyStatus(
    question: question,
    answeredToday: answered && question != null,
    streak: progress.streakOn(now),
  );
});
