import 'package:flutter/foundation.dart' show immutable;

import '../../content/domain/question.dart';
import 'attempt.dart';

/// What a practice session is made of; the key of `PracticeController`.
///
/// * [TemaPractice]: one tema, in bank order (attempt mode `practice`).
/// * [DailyPractice]: the "Continuar" queue (attempt mode `srs`).
/// * [MistakesPractice]: the Fallos list, optionally of one tema and optionally
///   starting at one question (attempt mode `review`).
/// * [MockMistakesPractice]: only the questions one finished mock got wrong or
///   left blank (attempt mode `review`).
/// * [FiguresPractice]: the "Cifras y plazos" mode, the questions flagged
///   `cifras` that the user may open (attempt mode `practice`).
/// * [DailyQuestionPractice]: the one "Pregunta del día" (attempt mode
///   `practice`); answering it also advances the daily streak.
@immutable
sealed class PracticeSource {
  const PracticeSource();

  /// The mode every attempt of this session is recorded with.
  AttemptMode get mode;
}

final class TemaPractice extends PracticeSource {
  const TemaPractice(this.tema);

  /// 1..7.
  final int tema;

  @override
  AttemptMode get mode => AttemptMode.practice;

  @override
  bool operator ==(Object other) => other is TemaPractice && other.tema == tema;

  @override
  int get hashCode => Object.hash(TemaPractice, tema);

  @override
  String toString() => 'TemaPractice($tema)';
}

final class DailyPractice extends PracticeSource {
  const DailyPractice();

  @override
  AttemptMode get mode => AttemptMode.srs;

  @override
  bool operator ==(Object other) => other is DailyPractice;

  @override
  int get hashCode => (DailyPractice).hashCode;

  @override
  String toString() => 'DailyPractice()';
}

final class MistakesPractice extends PracticeSource {
  const MistakesPractice([this.tema, this.from]);

  /// Limits the review to one tema; null = every mistake.
  final int? tema;

  /// Id of the question to start with (the row tapped in Fallos): the session
  /// starts there, goes on to the end of the list and then covers the ones
  /// before it, so nothing is left out. Null, or an id that is not in the
  /// list, = from the first.
  final String? from;

  @override
  AttemptMode get mode => AttemptMode.review;

  @override
  bool operator ==(Object other) =>
      other is MistakesPractice && other.tema == tema && other.from == from;

  @override
  int get hashCode => Object.hash(MistakesPractice, tema, from);

  @override
  String toString() => 'MistakesPractice($tema, from: $from)';
}

final class MockMistakesPractice extends PracticeSource {
  const MockMistakesPractice(this.mockId);

  /// The mock whose failed questions are reviewed.
  final int mockId;

  @override
  AttemptMode get mode => AttemptMode.review;

  @override
  bool operator ==(Object other) =>
      other is MockMistakesPractice && other.mockId == mockId;

  @override
  int get hashCode => Object.hash(MockMistakesPractice, mockId);

  @override
  String toString() => 'MockMistakesPractice($mockId)';
}

final class FiguresPractice extends PracticeSource {
  const FiguresPractice();

  @override
  AttemptMode get mode => AttemptMode.practice;

  @override
  bool operator ==(Object other) => other is FiguresPractice;

  @override
  int get hashCode => (FiguresPractice).hashCode;

  @override
  String toString() => 'FiguresPractice()';
}

final class DailyQuestionPractice extends PracticeSource {
  const DailyQuestionPractice(this.questionId);

  /// The question of the day (picked by `dailyStatusProvider`).
  final String questionId;

  @override
  AttemptMode get mode => AttemptMode.practice;

  @override
  bool operator ==(Object other) =>
      other is DailyQuestionPractice && other.questionId == questionId;

  @override
  int get hashCode => Object.hash(DailyQuestionPractice, questionId);

  @override
  String toString() => 'DailyQuestionPractice($questionId)';
}

/// [questions] rotated so that the one with id [from] comes first and the
/// ones before it go to the end (every question stays). Unchanged when [from]
/// is null or not in the list.
List<Question> startingAt(List<Question> questions, String? from) {
  final start = from == null ? -1 : questions.indexWhere((q) => q.id == from);
  if (start <= 0) return List.of(questions);
  return [...questions.sublist(start), ...questions.sublist(0, start)];
}

/// Order of a tema practice session (plan hito 3): bank order, starting at the
/// first question of the tema that was never answered ([answeredIds]) and
/// running to the end; when every question was answered once, the whole tema
/// from the start. Questions after the starting point that were already
/// answered are included again (this is practice, not a one-off pass).
///
/// [temaQuestions] must already be the tema's questions in bank order.
List<Question> temaPracticeOrder(
  List<Question> temaQuestions,
  Set<String> answeredIds,
) {
  final start = temaQuestions.indexWhere((q) => !answeredIds.contains(q.id));
  if (start <= 0) return List.of(temaQuestions);
  return temaQuestions.sublist(start);
}
