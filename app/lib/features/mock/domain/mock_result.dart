import 'package:flutter/foundation.dart' show immutable, mapEquals;

import '../../content/domain/question.dart';
import 'mock_config.dart';

/// Correct answers and number of questions of one tema within a mock.
typedef TemaScore = ({int correct, int total});

/// Outcome of a handed-in mock (plan 2.4).
@immutable
class MockResult {
  const MockResult({
    required this.correct,
    required this.wrong,
    required this.unanswered,
    required this.passed,
    required this.passMark,
    required this.perTema,
  });

  /// Right answers.
  final int correct;

  /// Not right: wrong answers **plus** the unanswered ones (a blank question
  /// counts as a failure). `correct + wrong` is the number of questions.
  final int wrong;

  /// Questions left blank (a subset of [wrong]).
  final int unanswered;

  /// `correct >= passMark` (`APTO`).
  final bool passed;
  final int passMark;

  /// Tema -> (correct, total), ascending by tema.
  final Map<int, TemaScore> perTema;

  int get total => correct + wrong;

  /// Wrong answers excluding the blank ones.
  int get answeredWrong => wrong - unanswered;

  @override
  bool operator ==(Object other) =>
      other is MockResult &&
      other.correct == correct &&
      other.wrong == wrong &&
      other.unanswered == unanswered &&
      other.passed == passed &&
      other.passMark == passMark &&
      mapEquals(other.perTema, perTema);

  @override
  int get hashCode => Object.hash(
    correct,
    wrong,
    unanswered,
    passed,
    passMark,
    Object.hashAllUnordered(
      perTema.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'MockResult($correct/$total, unanswered: $unanswered, passed: $passed)';
}

/// Scores a mock: [answers] holds, per question (same order as [questions]),
/// the 0-based option picked or null when left blank. A blank answer counts
/// as wrong; the mock is passed with `correct >= config.passMark`, so 16 is
/// `APTO` and 15 is not (plan 2.4).
///
/// Throws [ArgumentError] when the lists differ in length.
MockResult scoreMock({
  required List<Question> questions,
  required List<int?> answers,
  required MockConfig config,
}) {
  if (answers.length != questions.length) {
    throw ArgumentError.value(
      answers,
      'answers',
      'expected ${questions.length} answers, got ${answers.length}',
    );
  }
  var correct = 0;
  var unanswered = 0;
  final correctByTema = <int, int>{};
  final totalByTema = <int, int>{};
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final answer = answers[i];
    final isRight = answer != null && question.isCorrect(answer);
    if (answer == null) unanswered++;
    if (isRight) correct++;
    totalByTema[question.tema] = (totalByTema[question.tema] ?? 0) + 1;
    correctByTema[question.tema] =
        (correctByTema[question.tema] ?? 0) + (isRight ? 1 : 0);
  }
  final temas = totalByTema.keys.toList()..sort();
  return MockResult(
    correct: correct,
    wrong: questions.length - correct,
    unanswered: unanswered,
    passed: correct >= config.passMark,
    passMark: config.passMark,
    perTema: {
      for (final tema in temas)
        tema: (correct: correctByTema[tema]!, total: totalByTema[tema]!),
    },
  );
}
