import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/question.dart';
import '../../daily/application/daily_providers.dart';
import '../../mock/application/mock_providers.dart';
import '../../mistakes/application/mistakes_providers.dart';
import '../../srs/application/srs_providers.dart';
import '../domain/attempt.dart';
import '../domain/practice_source.dart';
import '../domain/quiz_session.dart';
import 'quiz_providers.dart';

/// What the practice screen shows.
@immutable
class PracticeState {
  const PracticeState({
    required this.session,
    this.saving = false,
    this.finished = false,
    this.saveErrors = 0,
  });

  /// The run through the questions; null when there is nothing to practise
  /// (empty daily queue, no mistakes).
  final QuizSession? session;

  /// True from the tap on an option until its attempt is stored.
  final bool saving;

  /// The user went past the last question: show the summary.
  final bool finished;

  /// How many answers failed to save (the screen shows a notice on each
  /// increase; the failed answer is taken back so it can be picked again).
  final int saveErrors;

  bool get isEmpty => session == null;

  PracticeState copyWith({
    QuizSession? session,
    bool? saving,
    bool? finished,
    int? saveErrors,
  }) => PracticeState(
    session: session ?? this.session,
    saving: saving ?? this.saving,
    finished: finished ?? this.finished,
    saveErrors: saveErrors ?? this.saveErrors,
  );
}

/// Drives one practice session (tema, daily queue, mistakes review, the
/// failed questions of one mock, the figures mode or the question of the day).
///
/// * The question list is fixed when the controller is built (a snapshot):
///   the daily queue and the Fallos list change under the user's feet as they
///   answer, the session must not.
/// * Each answer is stored **the moment it is picked** through
///   `StudyService.recordAnswers`, so progress survives closing the app.
///   Leaving the screen mid-session asks nothing: there is nothing to lose.
/// * Options are never shuffled.
class PracticeController extends AsyncNotifier<PracticeState> {
  PracticeController(this.source);

  final PracticeSource source;

  late DateTime _shownAt;
  var _disposed = false;

  @override
  Future<PracticeState> build() async {
    ref.onDispose(() => _disposed = true);
    // Riverpod 3 pauses a stream provider nobody listens to, and `read` does
    // not count: keep the attempts stream alive while the session runs.
    ref.listen(attemptsProvider, (previous, next) {});

    final questions = await ref.read(questionsProvider.future);
    final list = await _questionsFor(questions);
    _shownAt = ref.read(clockProvider)();
    if (list.isEmpty) return const PracticeState(session: null);
    return PracticeState(
      session: QuizSession(questions: list, mode: source.mode),
    );
  }

  Future<List<Question>> _questionsFor(List<Question> bank) async {
    final byId = {for (final question in bank) question.id: question};
    switch (source) {
      case TemaPractice(:final tema):
        final attempts = await ref.read(attemptsProvider.future);
        // A blank mock slot is stored as a miss with `selected == null`: the
        // question was never answered, so it must not move the resume point.
        final answered = {
          for (final attempt in attempts)
            if (attempt.selected != null) attempt.questionId,
        };
        return temaPracticeOrder([
          for (final question in bank)
            if (question.tema == tema) question,
        ], answered);
      case DailyPractice():
        final ids = await ref.read(dailyQueueProvider.future);
        return [for (final id in ids) ?byId[id]];
      case MistakesPractice(:final tema, :final from):
        final entries = await ref.read(mistakesProvider(tema).future);
        return startingAt([
          for (final entry in entries) ?byId[entry.questionId],
        ], from);
      case FiguresPractice():
        final attempts = await ref.read(attemptsProvider.future);
        final answered = {
          for (final attempt in attempts)
            if (attempt.selected != null) attempt.questionId,
        };
        // Figures use the same per-question access as any other review.
        return temaPracticeOrder([
          for (final question in bank)
            if (question.isFigures) question,
        ], answered);
      case DailyQuestionPractice(:final questionId):
        final question = byId[questionId];
        if (question == null) {
          return const [];
        }
        return [question];
      case MockMistakesPractice(:final mockId):
        final record = await ref.read(mockRepositoryProvider).byId(mockId);
        // An unfinished mock has no failures yet (every slot is still blank).
        if (record == null || !record.isFinished) {
          return const [];
        }
        return [
          for (var i = 0; i < record.questionIds.length; i++)
            if (byId[record.questionIds[i]] case final question?)
              if (record.answers[i] == null ||
                  !question.isCorrect(record.answers[i]!))
                question,
        ];
    }
  }

  /// Picks [option] (0-based) for the current question: locks it, and stores
  /// the attempt. A second pick on the same question does nothing. If the
  /// write fails the pick is taken back and [PracticeState.saveErrors]
  /// increases.
  Future<void> answer(int option) async {
    final current = state.value;
    final session = current?.session;
    if (current == null || session == null) return;
    if (current.saving || current.finished) return;
    if (session.isAnswered(session.currentIndex)) return;

    final question = session.currentQuestion;
    final now = ref.read(clockProvider)();
    final attempt = Attempt(
      questionId: question.id,
      mode: source.mode,
      selected: option,
      correct: question.isCorrect(option),
      answeredAt: now,
      // A clock moved by the user or the network must not store nonsense.
      elapsedMs: now
          .difference(_shownAt)
          .inMilliseconds
          .clamp(0, kMaxAttemptElapsedMs),
    );
    state = AsyncData(
      current.copyWith(session: session.select(option), saving: true),
    );
    // Taken before the await: the screen may be left while the answer saves,
    // and the streak must still advance (that notifier outlives this one).
    final daily = source is DailyQuestionPractice
        ? ref.read(dailyProgressProvider.notifier)
        : null;
    try {
      await ref.read(studyServiceProvider).recordAnswers([attempt]);
    } catch (_) {
      if (_disposed) return;
      state = AsyncData(
        current.copyWith(saving: false, saveErrors: current.saveErrors + 1),
      );
      return;
    }
    if (daily != null) {
      try {
        await daily.register(question.id);
      } on Object {
        // The answer is stored; a streak that fails to save is only a number.
      }
    }
    if (_disposed) return;
    state = AsyncData(state.requireValue.copyWith(saving: false));
  }

  /// Moves to the next question, or to the summary after the last one. Does
  /// nothing while the current question is unanswered or still saving.
  void next() {
    final current = state.value;
    final session = current?.session;
    if (current == null || session == null || current.finished) return;
    if (current.saving || !session.isAnswered(session.currentIndex)) return;
    _shownAt = ref.read(clockProvider)();
    if (session.isLastQuestion) {
      state = AsyncData(current.copyWith(finished: true));
    } else {
      state = AsyncData(current.copyWith(session: session.next()));
    }
  }
}

/// One controller per [PracticeSource]; disposed when the screen closes (the
/// next visit builds a fresh session).
final practiceControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PracticeController, PracticeState, PracticeSource>(
      PracticeController.new,
    );
