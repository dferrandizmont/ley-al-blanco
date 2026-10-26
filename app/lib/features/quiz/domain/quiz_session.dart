import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../../content/domain/question.dart';
import 'attempt.dart';

/// What the UI shows once a question has been checked: the option the user
/// picked (null for a mock question left blank) and the official answer.
@immutable
class AnswerFeedback {
  const AnswerFeedback({required this.selected, required this.correctIndex});

  /// 0-based option picked, or null when left unanswered.
  final int? selected;

  /// 0-based index of the official answer.
  final int correctIndex;

  bool get isCorrect => selected == correctIndex;

  @override
  bool operator ==(Object other) =>
      other is AnswerFeedback &&
      other.selected == selected &&
      other.correctIndex == correctIndex;

  @override
  int get hashCode => Object.hash(selected, correctIndex);

  @override
  String toString() =>
      'AnswerFeedback(selected: $selected, correct: $correctIndex)';
}

/// Immutable state machine of one run through a list of questions (plan 2.3).
///
/// Two behaviours, chosen by [mode]:
///
/// * `practice`, `review`, `srs` (see [hasImmediateFeedback]): the answer is
///   checked as soon as it is picked. A question can be answered **once**:
///   selecting again is a no-op (a double tap must not crash nor change the
///   answer), and [next]/[goTo] cannot skip an unanswered question.
/// * `mock`: no feedback until [submit]. The answer can be changed freely, the
///   navigator ([goTo]) can jump anywhere, and after [submit] the session is
///   read-only.
///
/// Options are never shuffled (plan 2.3): "Ambas respuestas son correctas"
/// depends on the questionnaire's A/B/C order. Every transition returns a new
/// session; the lists exposed are unmodifiable.
@immutable
class QuizSession {
  /// Builds a session, validating the inputs. [answers] defaults to all
  /// unanswered; pass it (with [currentIndex]/[submitted]) to resume a saved
  /// session.
  QuizSession({
    required List<Question> questions,
    required this.mode,
    this.currentIndex = 0,
    List<int?>? answers,
    this.submitted = false,
  }) : questions = List.unmodifiable(questions),
       answers = List.unmodifiable(
         answers ?? List<int?>.filled(questions.length, null),
       ) {
    if (questions.isEmpty) {
      throw ArgumentError.value(questions, 'questions', 'must not be empty');
    }
    if (this.answers.length != questions.length) {
      throw ArgumentError.value(
        answers,
        'answers',
        'must have one slot per question (${questions.length})',
      );
    }
    RangeError.checkValidIndex(currentIndex, questions, 'currentIndex');
    for (var i = 0; i < questions.length; i++) {
      final answer = this.answers[i];
      if (answer != null) {
        RangeError.checkValidIndex(answer, questions[i].options, 'answers[$i]');
      }
    }
    if (submitted && mode != AttemptMode.mock) {
      throw ArgumentError.value(
        submitted,
        'submitted',
        'only a mock can be submitted',
      );
    }
  }

  final List<Question> questions;
  final AttemptMode mode;
  final int currentIndex;

  /// Option picked per question (0-based), null while unanswered.
  final List<int?> answers;

  /// True once a mock has been handed in.
  final bool submitted;

  /// True for every mode but `mock`: the answer is checked when picked.
  bool get hasImmediateFeedback => mode != AttemptMode.mock;

  Question get currentQuestion => questions[currentIndex];
  int get length => questions.length;
  bool get isLastQuestion => currentIndex == questions.length - 1;

  bool isAnswered(int index) => answers[index] != null;

  int get answeredCount => answers.where((a) => a != null).length;

  /// Number of correct answers so far. In a mock the UI must not show it
  /// before [submit].
  int get correctCount {
    var count = 0;
    for (var i = 0; i < questions.length; i++) {
      final answer = answers[i];
      if (answer != null && questions[i].isCorrect(answer)) count++;
    }
    return count;
  }

  /// Practice-like modes: every question answered. Mock: handed in.
  bool get isFinished =>
      hasImmediateFeedback ? answeredCount == questions.length : submitted;

  /// What to show for question [index], or null when nothing may be shown:
  ///
  /// * immediate-feedback modes: null until answered;
  /// * mock: null until [submit]; afterwards also for blank questions
  ///   (`selected == null`, counted as wrong).
  AnswerFeedback? feedbackFor(int index) {
    final answer = answers[index];
    if (hasImmediateFeedback ? answer == null : !submitted) return null;
    return AnswerFeedback(
      selected: answer,
      correctIndex: questions[index].answer,
    );
  }

  /// Picks [option] (0-based) for the current question. See the class docs
  /// for the per-mode rules; a refused change returns `this`.
  ///
  /// Throws [RangeError] when [option] is not an option of the question.
  QuizSession select(int option) {
    RangeError.checkValidIndex(option, currentQuestion.options, 'option');
    if (submitted) return this;
    if (hasImmediateFeedback && isAnswered(currentIndex)) return this;
    final updated = List<int?>.of(answers)..[currentIndex] = option;
    return _copyWith(answers: updated);
  }

  /// Moves to the next question. No-op on the last one, and, in
  /// immediate-feedback modes, while the current one is unanswered.
  QuizSession next() {
    if (isLastQuestion) return this;
    if (hasImmediateFeedback && !isAnswered(currentIndex)) return this;
    return _copyWith(currentIndex: currentIndex + 1);
  }

  /// Moves to the previous question (no-op on the first).
  QuizSession previous() {
    if (currentIndex == 0) return this;
    return _copyWith(currentIndex: currentIndex - 1);
  }

  /// Jumps to question [index] (the mock navigator). In immediate-feedback
  /// modes it cannot go beyond the first unanswered question (no-op).
  ///
  /// Throws [RangeError] when [index] is out of range.
  QuizSession goTo(int index) {
    RangeError.checkValidIndex(index, questions, 'index');
    if (hasImmediateFeedback && index > _firstUnansweredIndex) return this;
    return _copyWith(currentIndex: index);
  }

  /// Hands in a mock: from now on it is read-only and feedback is available.
  /// Submitting twice is a no-op. Throws [StateError] in other modes.
  QuizSession submit() {
    if (hasImmediateFeedback) {
      throw StateError('Only a mock can be submitted (mode: ${mode.name}).');
    }
    if (submitted) return this;
    return _copyWith(submitted: true);
  }

  /// The attempts to persist, all stamped with [now] (the caller owns the
  /// clock).
  ///
  /// * mock: one per question, blank ones included (`selected: null`,
  ///   `correct: false`); [mockId] links them to the stored mock. Throws
  ///   [StateError] before [submit].
  /// * other modes: one per answered question.
  List<Attempt> toAttempts({required DateTime now, int? mockId}) {
    if (!hasImmediateFeedback && !submitted) {
      throw StateError('A mock produces attempts only after submit().');
    }
    final attempts = <Attempt>[];
    for (var i = 0; i < questions.length; i++) {
      final answer = answers[i];
      if (hasImmediateFeedback && answer == null) continue;
      attempts.add(
        Attempt(
          questionId: questions[i].id,
          mode: mode,
          selected: answer,
          correct: answer != null && questions[i].isCorrect(answer),
          answeredAt: now,
          mockId: mockId,
        ),
      );
    }
    return attempts;
  }

  int get _firstUnansweredIndex {
    final index = answers.indexWhere((a) => a == null);
    return index == -1 ? questions.length : index;
  }

  QuizSession _copyWith({
    int? currentIndex,
    List<int?>? answers,
    bool? submitted,
  }) => QuizSession(
    questions: questions,
    mode: mode,
    currentIndex: currentIndex ?? this.currentIndex,
    answers: answers ?? this.answers,
    submitted: submitted ?? this.submitted,
  );

  @override
  bool operator ==(Object other) =>
      other is QuizSession &&
      other.mode == mode &&
      other.currentIndex == currentIndex &&
      other.submitted == submitted &&
      listEquals(other.questions, questions) &&
      listEquals(other.answers, answers);

  @override
  int get hashCode => Object.hash(
    mode,
    currentIndex,
    submitted,
    Object.hashAll(questions.map((q) => q.id)),
    Object.hashAll(answers),
  );

  @override
  String toString() =>
      'QuizSession(${mode.name}, $currentIndex/${questions.length}, '
      'answered: $answeredCount, submitted: $submitted)';
}
