import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/explanation_body.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/progress_header.dart';
import 'package:apto_armas/core/widgets/raised_card.dart';
import 'package:apto_armas/core/widgets/round_icon_button.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/bank_content_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

Question _current(WidgetTester tester, PracticeSource source) =>
    containerOf(tester)
        .read(practiceControllerProvider(source))
        .requireValue
        .session!
        .currentQuestion;

void main() {
  const tema1 = TemaPractice(1);

  testScreen('right answer: check icon, inline explanation, Siguiente', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpFullApp(tester);
    await openRoute(tester, '/tema/1');
    expect(find.byType(OptionCard), findsNWidgets(3));
    expect(find.text('1 de 68 pendientes'), findsOneWidget);
    expect(find.byType(ProgressHeader), findsOneWidget);

    final q = _current(tester, tema1);
    await tapOption(tester, q.answer);

    // The tapped card is green with a check icon (never colour alone).
    final states = optionStates(tester);
    expect(states[q.answer], OptionState.correct);
    expect(
      find.descendant(
        of: find.byType(OptionCard).at(q.answer),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    // The explanation opened inside the question card (no modal sheet) with
    // the verdict, the bank's own explanation / article / notice, and
    // "Siguiente" stays below the scrolling content.
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.descendant(
        of: find.byType(RaisedCard),
        matching: find.byType(ExplanationBody),
      ),
      findsOneWidget,
    );
    expect(find.text('Correcto'), findsOneWidget);
    expectBankContent(q);
    expect(find.widgetWithText(FilledButton, 'Siguiente'), findsOneWidget);

    // The attempt is already stored (practice mode, correct).
    final attempts = await containerOf(tester).read(attemptsProvider.future);
    expect(attempts, hasLength(1));
    expect(attempts.single.questionId, q.id);
    expect(attempts.single.mode, AttemptMode.practice);
    expect(attempts.single.selected, q.answer);
    expect(attempts.single.correct, isTrue);

    // Siguiente: next question, nothing selected, header moves on.
    await tapNext(tester);
    expect(find.byType(ExplanationBody), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Siguiente'), findsNothing);
    expect(find.text('2 de 68 pendientes'), findsOneWidget);
    expect(optionStates(tester), everyElement(OptionState.idle));
    semantics.dispose();
  });

  testWidgets('OptionCard speaks "Correcta" / "Incorrecta"', (tester) async {
    final semantics = tester.ensureSemantics();
    Future<void> pump(OptionState state) => pumpApp(
      tester,
      Scaffold(
        body: OptionCard(letter: 'B', text: 'Una opción', state: state),
      ),
    );
    Future<String> label() async =>
        tester.getSemantics(find.byType(OptionCard)).label;

    await pump(OptionState.correct);
    expect(await label(), contains('Opción B: Una opción'));
    expect(await label(), contains('Correcta'));
    await pump(OptionState.revealedCorrect);
    expect(await label(), contains('Correcta'));
    await pump(OptionState.incorrect);
    expect(await label(), contains('Incorrecta'));
    await pump(OptionState.idle);
    expect(await label(), isNot(contains('rrecta')));
    semantics.dispose();
  });

  testScreen('wrong answer: cross on the pick, correct one revealed', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await openRoute(tester, '/tema/1');
    final q = _current(tester, tema1);
    final wrong = wrongOption(q);
    await tapOption(tester, wrong);

    final states = optionStates(tester);
    expect(states[wrong], OptionState.incorrect);
    expect(states[q.answer], OptionState.revealedCorrect);
    expect(
      find.descendant(
        of: find.byType(OptionCard).at(wrong),
        matching: find.byIcon(Icons.close_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OptionCard).at(q.answer),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('Incorrecto'), findsOneWidget);
    final letter = String.fromCharCode(0x41 + q.answer);
    expect(
      find.text('$letter. ${q.options[q.answer]}'),
      findsOneWidget,
      reason: 'the explanation states the right answer',
    );

    final attempts = await containerOf(tester).read(attemptsProvider.future);
    expect(attempts.single.correct, isFalse);
    expect(attempts.single.selected, wrong);
  });

  testScreen('a locked question ignores a second tap', (tester) async {
    await pumpFullApp(tester);
    await openRoute(tester, '/tema/1');
    final q = _current(tester, tema1);
    await tapOption(tester, q.answer);
    await tester.tap(find.byType(OptionCard).at(wrongOption(q)));
    await tester.pumpAndSettle();
    final attempts = await containerOf(tester).read(attemptsProvider.future);
    expect(attempts, hasLength(1));
    expect(optionStates(tester)[wrongOption(q)], OptionState.idle);
  });

  testScreen('the explanation stays in the card and Siguiente stays pinned', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await openRoute(tester, '/tema/1');
    // Nothing to advance to before answering.
    expect(find.widgetWithText(FilledButton, 'Siguiente'), findsNothing);
    final q = _current(tester, tema1);
    await tapOption(tester, q.answer);

    // There is nothing to dismiss: tapping the screen edge changes nothing.
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.byType(ExplanationBody), findsOneWidget);
    expect(find.text('Correcto'), findsOneWidget);

    // The pinned pill sits 24 dp above the bottom edge, 56 dp tall.
    final next = find.widgetWithText(FilledButton, 'Siguiente');
    final rect = tester.getRect(next);
    final screen = tester.getRect(find.byType(Scaffold));
    expect(rect.height, 56);
    expect(screen.bottom - rect.bottom, 24);
    // The button has its own area below the scroll; only section spacing
    // remains at the bottom of the scrolling content.
    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('question-0')),
    );
    expect(scroll.padding!.resolve(TextDirection.ltr).bottom, Sp.section);
    expect(tester.getRect(find.byWidget(scroll)).bottom, lessThan(rect.top));

    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('2 de 68 pendientes'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Siguiente'), findsNothing);
  });

  testScreen('the close button leaves the session', (tester) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/tema/2');
    expect(locationOf(tester), '/tema/2');
    await tester.tap(find.byType(RoundIconButton));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/');

    // Opened as the only page (nothing to pop to): goes to Inicio too.
    await openRoute(tester, '/tema/3');
    await tester.tap(find.byType(RoundIconButton));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/');
  });

  testScreen('tema 7 to the end: "Terminar" then the summary', (tester) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/tema/7');
    const source = TemaPractice(7);
    expect(find.text('1 de 22 pendientes'), findsOneWidget);

    for (var i = 0; i < 22; i++) {
      final q = _current(tester, source);
      // Miss the last two.
      await tapOption(tester, i < 20 ? q.answer : wrongOption(q));
      await tapNext(tester, label: i == 21 ? 'Terminar' : 'Siguiente');
    }

    expect(find.text('Sesión terminada'), findsOneWidget);
    expect(find.text('20 / 22'), findsOneWidget);
    expect(find.text('Aciertos'), findsOneWidget);
    final attempts = await containerOf(tester).read(attemptsProvider.future);
    expect(attempts, hasLength(22));
    expect(attempts.where((a) => !a.correct), hasLength(2));

    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/');
    // 20 right + 2 wrong are reflected on Inicio.
    expect(find.text('2 fallos pendientes'), findsOneWidget);
  });

  testScreen('tema practice starts at the first never-answered question', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final bank = await bankOf(tester);
    final tema3 = bank.where((q) => q.tema == 3).toList();
    await containerOf(tester).read(studyServiceProvider).recordAnswers([
      for (final q in tema3.take(5)) attemptOn(q, correct: true),
    ]);
    await tester.pumpAndSettle();

    await openRoute(tester, '/tema/3');
    expect(
      _current(tester, const TemaPractice(3)).id,
      tema3[5].id,
      reason: 'questions 1-5 were answered, so it resumes at the sixth',
    );
    expect(find.text('1 de 61 pendientes'), findsOneWidget);
  });

  testScreen('daily queue runs in srs mode and shows the 15 questions', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await openRoute(tester, '/repaso');
    expect(find.text('REPASO DEL DÍA'), findsOneWidget);
    // The daily queue keeps the plain ratio: "pendientes" is for the
    // practice by tema.
    expect(find.text('1 / 15'), findsOneWidget);
    expect(find.text('1 de 15 pendientes'), findsNothing);
    final q = _current(tester, const DailyPractice());
    await tapOption(tester, q.answer);
    final attempts = await containerOf(tester).read(attemptsProvider.future);
    expect(attempts.single.mode, AttemptMode.srs);
    // The Leitner card moved too.
    final card = await containerOf(tester)
        .read(srsRepositoryProvider)
        .get(q.id);
    expect(card, isNotNull);
  });

  testScreen('an empty daily queue says so', (tester) async {
    await pumpFullApp(tester);
    final c = containerOf(tester);
    final bank = await bankOf(tester);
    final byId = {for (final q in bank) q.id: q};
    for (final id in await c.read(dailyQueueProvider.future)) {
      await c.read(studyServiceProvider).recordAnswers([
        attemptOn(byId[id]!, correct: true),
      ]);
    }
    await tester.pumpAndSettle();
    await openRoute(tester, '/repaso');
    expect(find.text('Hoy no quedan preguntas'), findsOneWidget);
    expect(find.text('Volver al inicio'), findsOneWidget);
    expect(find.byType(OptionCard), findsNothing);
  });

  testScreen('mistakes review: only the mistakes, in review mode', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final c = containerOf(tester);
    final bank = await bankOf(tester);
    final failed = [
      bank.firstWhere((q) => q.tema == 2),
      bank.firstWhere((q) => q.tema == 5),
    ];
    await c.read(studyServiceProvider).recordAnswers([
      for (final q in failed) attemptOn(q, correct: false),
    ]);
    await tester.pumpAndSettle();

    await openRoute(tester, '/fallos/repasar?tema=5');
    expect(find.text('REPASAR FALLOS'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('1 de 1 pendiente'), findsNothing);
    final q = _current(tester, const MistakesPractice(5));
    expect(q.id, failed[1].id);
    await tapOption(tester, q.answer);
    final attempts = await c.read(attemptsProvider.future);
    expect(attempts.last.mode, AttemptMode.review);
    expect(attempts.last.correct, isTrue);
    await tapNext(tester, label: 'Terminar');
    expect(find.text('1 / 1'), findsOneWidget); // summary: 1 of 1
    expect(find.text('Sesión terminada'), findsOneWidget);
  });
}
