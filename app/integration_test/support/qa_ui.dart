import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'qa_bank.dart';
import 'qa_harness.dart';
import 'qa_texts.dart';

// ---------------------------------------------------------------- Inicio

/// Waits for Inicio to be the visible screen.
Future<void> waitHome(QaApp app) async {
  await app.tester.waitFor(
    find.byType(TemaCard),
    count: 7,
    reason: 'Inicio (7 temas)',
  );
  await app.tester.pumpFor(const Duration(milliseconds: 300));
}

/// How many lock icons Inicio shows (the Simulacro tile and the temas).
int lockIcons() => find.byIcon(Icons.lock_rounded).evaluate().length;

/// The row of tema [n] (1..7) on Inicio.
Finder temaCard(int n) => find.byType(TemaCard).at(n - 1);

/// Opens the practice of tema [n] from Inicio.
Future<void> openTema(QaApp app, int n) async {
  await app.tester.tapFinder(temaCard(n), reason: 'tema $n on Inicio');
}

/// The round "Cerrar" button of the practice and mock headers.
Finder closeButton() => find.byTooltip(T.cerrar);

/// Closes the practice screen and waits for Inicio.
Future<void> closePracticeToHome(QaApp app) async {
  await app.tester.tapFinder(closeButton(), reason: 'close button');
  await waitHome(app);
}

// ------------------------------------------------------------- Questions

/// The bank question on screen (practice, daily queue, mistakes or mock),
/// found from its option texts and stem. With [notId], waits until the screen
/// shows a different question (after "Siguiente").
Future<QaQuestion> currentQuestion(QaApp app, {String? notId}) async {
  final tester = app.tester;
  QaQuestion? found;
  await tester.waitUntil(() {
    final options = [
      for (final e in find.byType(OptionCard).evaluate())
        (e.widget as OptionCard).text,
    ];
    if (options.length < 2) return false;
    final q = app.bank.identify(options, tester.visibleTexts());
    if (q == null || q.id == notId) return false;
    found = q;
    return true;
  }, reason: 'a question of the bank on screen');
  return found!;
}

/// The visual state of each option card on screen.
List<OptionState> optionStates() => [
  for (final e in find.byType(OptionCard).evaluate())
    (e.widget as OptionCard).state,
];

/// Picks option [index] of the question on screen.
Future<void> pickOption(QaApp app, int index) => app.tester.tapFinder(
  find.byType(OptionCard).at(index),
  reason: 'option ${String.fromCharCode(65 + index)}',
  wait: const Duration(milliseconds: 250),
);

// -------------------------------------------------------------- Practice

/// Answers the question on screen (practice style: feedback appears) right or
/// wrong, waits for the feedback and returns the question.
Future<QaQuestion> answerPractice(QaApp app, {required bool correct}) async {
  final q = await currentQuestion(app);
  await pickOption(app, correct ? q.answer : q.wrongOption);
  await app.tester.waitUntil(
    () => app.tester.hasText(T.siguiente) || app.tester.hasText(T.terminar),
    reason: 'the feedback and the "Siguiente" button',
  );
  return q;
}

/// Answers a run of questions in a practice screen: `true` = right, `false`
/// = wrong. Stays on the feedback of the last one answered. Returns the
/// questions in order.
Future<List<QaQuestion>> practiceRun(QaApp app, List<bool> results) async {
  final answered = <QaQuestion>[];
  for (final (i, ok) in results.indexed) {
    if (i > 0) {
      await app.tester.tapText(T.siguiente);
      await currentQuestion(app, notId: answered.last.id);
    }
    answered.add(await answerPractice(app, correct: ok));
  }
  return answered;
}

// ----------------------------------------------------------------- Mock

/// What a scenario did with one question of a mock.
class MockPick {
  const MockPick(this.number, this.question, this.outcome);

  /// 1-based position in the mock.
  final int number;
  final QaQuestion question;

  /// `true` = right, `false` = wrong, `null` = left blank.
  final bool? outcome;
}

/// Starts the mock from Inicio (the Simulacro tile, then "Empezar") and waits
/// for question 1.
Future<void> startMockFromHome(QaApp app) async {
  await app.tester.tapText(T.simulacro);
  await app.tester.tapText(T.empezar);
  await app.tester.waitFor(
    find.text(T.ratio(1, 20)),
    reason: 'the first question of the mock',
  );
}

/// Opens the navigator ("Preguntas") and taps the cell of question [number].
Future<void> goToQuestion(QaApp app, int number) async {
  final tester = app.tester;
  await tester.tapText(T.preguntas);
  await tester.waitFor(find.byType(MockNavigator), reason: 'the navigator');
  await tester.tapFinder(
    find.descendant(
      of: find.byType(MockNavigator),
      matching: find.text('$number'),
    ),
    reason: 'navigator cell $number',
  );
  await tester.waitGone(find.byType(MockNavigator));
  await tester.waitFor(find.text(T.ratio(number, 20)));
}

/// The numbers the navigator marks as answered (1-based), read from the
/// widget, with the sheet opened and closed again.
Future<Set<int>> navigatorAnswered(QaApp app) async {
  final tester = app.tester;
  await tester.tapText(T.preguntas);
  await tester.waitFor(find.byType(MockNavigator), reason: 'the navigator');
  final widget = tester.widget<MockNavigator>(find.byType(MockNavigator));
  final answered = {for (final i in widget.answered) i + 1};
  // Tap the current cell: the sheet closes on the same question.
  await tester.tapFinder(
    find.descendant(
      of: find.byType(MockNavigator),
      matching: find.text('${widget.current + 1}'),
    ),
  );
  await tester.waitGone(find.byType(MockNavigator));
  return answered;
}

/// Answers the question on screen in a mock (no feedback: the option just
/// turns "selected"). [outcome] `null` leaves it blank. Returns the pick.
Future<MockPick> answerMock(
  QaApp app,
  int number, {
  required bool? outcome,
  String? previousId,
}) async {
  final q = await currentQuestion(app, notId: previousId);
  if (outcome != null) {
    final index = outcome ? q.answer : q.wrongOption;
    await pickOption(app, index);
    final states = optionStates();
    if (states[index] != OptionState.selected) {
      throw TestFailure(
        'Mock question $number: option $index should be selected, '
        'states are $states',
      );
    }
  }
  return MockPick(number, q, outcome);
}

/// Plays the whole mock. Questions in [wrong] (1-based) are answered wrong,
/// those in [blank] are left blank, the rest right. Questions
/// [navigatorFrom]..20 are visited in reverse order **through the navigator**
/// (the earlier ones in order, with "Siguiente"). Returns the picks by
/// number. Leaves the mock on screen, not handed in.
Future<List<MockPick>> playMock(
  QaApp app, {
  Set<int> wrong = const {},
  Set<int> blank = const {},
  int navigatorFrom = 21,
}) async {
  final tester = app.tester;
  final picks = <int, MockPick>{};
  bool? outcomeOf(int n) => blank.contains(n) ? null : !wrong.contains(n);

  String? previous;
  for (var n = 1; n < navigatorFrom && n <= 20; n++) {
    if (n > 1) {
      await tester.tapText(T.siguiente);
      await tester.waitFor(find.text(T.ratio(n, 20)));
    }
    final pick = await answerMock(
      app,
      n,
      outcome: outcomeOf(n),
      previousId: previous,
    );
    picks[n] = pick;
    previous = pick.question.id;
  }
  for (var n = 20; n >= navigatorFrom; n--) {
    await goToQuestion(app, n);
    final pick = await answerMock(
      app,
      n,
      outcome: outcomeOf(n),
      previousId: previous,
    );
    picks[n] = pick;
    previous = pick.question.id;
  }
  return [for (var n = 1; n <= 20; n++) picks[n]!];
}

/// Taps "Entregar", checks the dialog says [body] and confirms; waits for the
/// result screen.
Future<void> submitMock(QaApp app, {required String body}) async {
  final tester = app.tester;
  await tester.tapText(T.entregar);
  final dialog = find.byType(AlertDialog);
  await tester.waitFor(dialog, reason: 'the "Entregar" dialog');
  expect(
    find.descendant(of: dialog, matching: find.text(T.entregarTitulo)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: dialog, matching: find.text(body)),
    findsOneWidget,
    reason: 'dialog body. On screen: ${tester.visibleTexts().join(' | ')}',
  );
  await tester.tapFinder(
    find.descendant(of: dialog, matching: find.text(T.entregar)),
    reason: 'confirm button of the dialog',
  );
  await tester.waitFor(
    find.text(T.deVeinte),
    timeout: const Duration(seconds: 30),
    reason: 'the result of the mock',
  );
  await tester.pumpFor(const Duration(milliseconds: 400));
}

/// The "a / b" texts of the per-tema card of the result, in tema order.
List<String> resultRatios(WidgetTester tester) {
  final ratio = RegExp(r'^\d+ / \d+$');
  return tester.visibleTexts().where(ratio.hasMatch).toList();
}

/// Expected "a / b" per tema (ascending) for [picks]: blank and wrong count
/// as misses.
List<String> expectedRatios(List<MockPick> picks) {
  final correct = <int, int>{};
  final total = <int, int>{};
  for (final p in picks) {
    total.update(p.question.tema, (n) => n + 1, ifAbsent: () => 1);
    correct.putIfAbsent(p.question.tema, () => 0);
    if (p.outcome == true) correct.update(p.question.tema, (n) => n + 1);
  }
  return [
    for (final tema in (total.keys.toList()..sort()))
      T.ratio(correct[tema]!, total[tema]!),
  ];
}

/// Taps the close button of the mock, which asks to confirm.
Future<void> askToLeaveMock(QaApp app) async {
  await app.tester.tapFinder(closeButton(), reason: 'close button of the mock');
  await app.tester.waitFor(
    find.text(T.salirTitulo),
    reason: 'the "Salir del simulacro" dialog',
  );
}

/// Confirms the leave dialog ("Salir") and waits for Inicio.
Future<void> confirmLeaveMock(QaApp app) async {
  await app.tester.tapFinder(
    find.descendant(of: find.byType(AlertDialog), matching: find.text(T.salir)),
  );
  await waitHome(app);
}
