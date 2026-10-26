import 'package:flutter/foundation.dart' show immutable, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/application/content_providers.dart';
import '../../content/domain/question.dart';
import '../../quiz/domain/attempt.dart';
import '../../quiz/domain/quiz_session.dart';
import '../data/mock_repository.dart';
import '../domain/mock_config.dart';
import '../domain/mock_result.dart';
import 'mock_providers.dart';

/// What the running-mock screen shows.
@immutable
class MockState {
  const MockState({
    required this.mockId,
    required this.timed,
    required this.startedAt,
    required this.session,
    this.submitting = false,
    this.flagged = const {},
  });

  final int mockId;

  /// Whether the user asked for the indicative countdown.
  final bool timed;
  final DateTime startedAt;

  /// Mock-mode session: no feedback, freely navigable, read-only once
  /// submitted.
  final QuizSession session;

  /// True while `finishMock` runs.
  final bool submitting;

  /// Ids of the questions the user marked as doubtful. They are saved with
  /// the mock, so they survive leaving it or the process being killed.
  final Set<String> flagged;

  /// Whether question [index] (exam order) is marked as doubtful.
  bool isFlagged(int index) => flagged.contains(session.questions[index].id);

  /// Indices (exam order) of the questions marked as doubtful.
  Set<int> get flaggedIndices => {
    for (var i = 0; i < session.length; i++)
      if (isFlagged(i)) i,
  };

  /// Number of questions marked as doubtful.
  int get flaggedCount => flaggedIndices.length;

  /// Number of questions with no answer.
  int get unansweredCount => session.length - session.answeredCount;

  /// The mock was handed in (this run, or opened already finished).
  bool get isSubmitted => session.submitted;

  MockState copyWith({
    QuizSession? session,
    bool? submitting,
    Set<String>? flagged,
  }) => MockState(
    mockId: mockId,
    timed: timed,
    startedAt: startedAt,
    session: session ?? this.session,
    submitting: submitting ?? this.submitting,
    flagged: flagged ?? this.flagged,
  );
}

/// Drives one mock exam, keyed by its row id in `mocks`.
///
/// Everything is rebuilt from the stored [MockRecord] (questions in exam
/// order, answers so far), and **every change of answer is saved** with
/// `MockRepository.saveAnswers`, so an interrupted mock keeps its answers in
/// the database. Leaving the mock (or Android killing the app) leaves it open,
/// not abandoned: Simulacro and Inicio offer "Continuar simulacro" for the
/// latest unfinished one (`unfinishedMockProvider`), which opens this route
/// and rebuilds the mock exactly as it was left. The app asks before leaving.
class MockController extends AsyncNotifier<MockState> {
  MockController(this.mockId);

  final int mockId;

  Future<void> _saves = Future.value();

  /// Completes when every queued answer-sheet save has finished.
  @visibleForTesting
  Future<void> get pendingSaves => _saves;

  @override
  Future<MockState> build() async {
    final record = await ref.read(mockRepositoryProvider).byId(mockId);
    if (record == null) {
      throw ArgumentError.value(mockId, 'mockId', 'No such mock');
    }
    final questions = await ref
        .read(questionRepositoryProvider)
        .byIds(record.questionIds);
    if (questions.length != record.questionIds.length) {
      throw StateError('Mock $mockId has questions missing from the bank.');
    }
    return MockState(
      mockId: mockId,
      timed: record.timed,
      startedAt: record.startedAt,
      session: QuizSession(
        questions: questions,
        mode: AttemptMode.mock,
        answers: record.answers,
        submitted: record.isFinished,
      ),
      flagged: record.flagged.toSet(),
    );
  }

  /// Picks (or changes) the answer of the current question and saves the
  /// answer sheet.
  void select(int option) => _update((s) => s.select(option), save: true);

  /// Marks the current question as doubtful, or takes the mark off, and
  /// saves it with the mock.
  void toggleFlag() {
    final current = state.value;
    if (current == null || current.isSubmitted || current.submitting) return;
    final id = current.session.currentQuestion.id;
    final flagged = {...current.flagged};
    if (!flagged.remove(id)) flagged.add(id);
    state = AsyncData(current.copyWith(flagged: flagged));
    _enqueue((repository) => repository.saveFlagged(mockId, flagged));
  }

  void goTo(int index) => _update((s) => s.goTo(index));
  void next() => _update((s) => s.next());
  void previous() => _update((s) => s.previous());

  void _update(QuizSession Function(QuizSession) change, {bool save = false}) {
    final current = state.value;
    if (current == null || current.isSubmitted || current.submitting) return;
    final updated = change(current.session);
    if (identical(updated, current.session) || updated == current.session) {
      return;
    }
    state = AsyncData(current.copyWith(session: updated));
    if (save) {
      _enqueue((repository) => repository.saveAnswers(mockId, updated.answers));
    }
  }

  /// Queues a write of the mock's in-progress state: saves go one after the
  /// other, in the order they were asked.
  void _enqueue(Future<void> Function(MockRepository repository) write) {
    final repository = ref.read(mockRepositoryProvider);
    _saves = _saves
        .then((_) => write(repository))
        // A failed intermediate save loses nothing for the answers:
        // `finishMock` writes the final sheet again. A lost mark is the only
        // thing that can be missed, and the next change saves them all.
        .catchError((Object _) {});
  }

  /// Hands the mock in: waits for pending saves, scores it, stores the result
  /// and the attempts (one transaction, see `MockService.finishMock`).
  /// Rethrows when that fails; the mock then stays open and can be handed in
  /// again.
  ///
  /// The screen blocks leaving while this runs, but the controller is
  /// auto-disposed whenever nobody listens, so every write to [state] after
  /// an `await` checks [Ref.mounted] first: the transaction may commit after
  /// the controller is gone, and a disposed notifier throws on `state =`. The
  /// result is still returned to the caller in that case.
  Future<MockResult> submit() async {
    final current = state.value;
    if (current == null) throw StateError('The mock is not loaded.');
    if (current.submitting) throw StateError('Already submitting.');
    // Saving may outlive the screen. Capture dependencies while this ref is
    // mounted, before waiting for the queued answer-sheet writes.
    final service = ref.read(mockServiceProvider);
    state = AsyncData(current.copyWith(submitting: true));
    try {
      await _saves;
      final submitted = current.session.submit();
      final result = await service.finishMock(mockId, submitted);
      if (ref.mounted) {
        state = AsyncData(
          current.copyWith(session: submitted, submitting: false),
        );
      }
      return result;
    } catch (_) {
      if (ref.mounted) state = AsyncData(current.copyWith(submitting: false));
      rethrow;
    }
  }
}

final mockControllerProvider = AsyncNotifierProvider.autoDispose
    .family<MockController, MockState, int>(MockController.new);

/// A finished (or open) mock with its questions and score, for the result and
/// review screens. Null when the mock does not exist.
@immutable
class MockOutcome {
  const MockOutcome({
    required this.record,
    required this.questions,
    required this.result,
  });

  final MockRecord record;

  /// In exam order.
  final List<Question> questions;

  /// The score. The verdict, the right-answer count and the pass mark are the
  /// ones **stored** when the mock was handed in (a later change of the exam
  /// config must not flip an old verdict); only the per-tema breakdown is
  /// recomputed from the stored answers.
  final MockResult result;

  /// Indices (exam order) of the questions not answered right, blank ones
  /// included.
  List<int> get failedIndices => [
    for (var i = 0; i < questions.length; i++)
      if (record.answers[i] == null ||
          !questions[i].isCorrect(record.answers[i]!))
        i,
  ];
}

final mockOutcomeProvider = FutureProvider.autoDispose
    .family<MockOutcome?, int>((ref, mockId) async {
      final record = await ref.watch(mockRepositoryProvider).byId(mockId);
      if (record == null) return null;
      final questions = await ref
          .watch(questionRepositoryProvider)
          .byIds(record.questionIds);
      if (questions.length != record.questionIds.length) {
        throw StateError('Mock $mockId has questions missing from the bank.');
      }
      // Mocks finished before schema v2 did not store their pass mark: the
      // current config is the best available explanation for those. An
      // unfinished mock shows no verdict, so its field is only a placeholder.
      final int passMark;
      if (record.passMark case final stored?) {
        passMark = stored;
      } else if (record.isFinished) {
        passMark = (await ref.watch(mockConfigProvider.future)).passMark;
      } else {
        passMark = questions.length;
      }
      final scored = scoreMock(
        questions: questions,
        answers: record.answers,
        config: MockConfig(
          size: questions.length,
          passMark: passMark.clamp(1, questions.length),
        ),
      );
      final correct = record.correct ?? scored.correct;
      return MockOutcome(
        record: record,
        questions: questions,
        result: MockResult(
          correct: correct,
          wrong: questions.length - correct,
          unanswered: scored.unanswered,
          passed: record.passed ?? scored.passed,
          passMark: passMark,
          perTema: scored.perTema,
        ),
      );
    });
