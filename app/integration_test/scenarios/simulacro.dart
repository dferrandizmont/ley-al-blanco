import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/score_ring.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';
import '../support/qa_ui.dart';

/// The numbers of the rows of "Preguntas falladas" on the result screen
/// ("3. Enunciado..." -> 3).
Set<int> failedRowNumbers(WidgetTester tester) {
  final row = RegExp(r'^(\d+)\. ');
  return {
    for (final text in tester.visibleTexts())
      if (row.firstMatch(text) case final m?) int.parse(m.group(1)!),
  };
}

/// The big number in the score ring of the result.
Finder ringScore(String score) =>
    find.descendant(of: find.byType(ScoreRing), matching: find.text(score));

/// The failed row of question [number] on the result screen.
Finder failedRow(int number) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').startsWith('$number. '),
);

void registerSimulacro() {
  qaScenario(
    'simulacro_aprobado',
    '16 aciertos y 4 fallos: APTO, reparto por tema y repaso de exactamente 4',
    (tester) async {
      final app = await launchApp(tester);
      await tester.tapText(T.simulacro);
      expect(find.textContaining('Se aprueba con 16 aciertos'), findsOneWidget);
      await tester.tapText(T.empezar);
      await tester.waitFor(find.text(T.ratio(1, 20)));
      // No feedback in a mock: no verdict, no "Siguiente"-gated explanation.
      expect(find.text(T.explicacion), findsNothing);

      // 1-10 in order, 20 down to 11 through the navigator.
      const wrong = {3, 6, 9, 13};
      final picks = await playMock(app, wrong: wrong, navigatorFrom: 11);
      expect(await navigatorAnswered(app), {for (var i = 1; i <= 20; i++) i});

      // The question answered first still shows its choice.
      await goToQuestion(app, 1);
      final first = picks.first;
      expect(
        optionStates()[first.question.answer],
        OptionState.selected,
        reason: 'question 1 keeps its answer',
      );

      await submitMock(app, body: T.entregarTodas);
      expect(find.text(T.apto), findsOneWidget);
      expect(find.text(T.noApto), findsNothing);
      expect(ringScore('16'), findsOneWidget);
      expect(find.text(T.deVeinte), findsOneWidget);
      expect(find.text(T.marcaAprobado), findsOneWidget);

      // Per tema: 3/3/3/4/3/3/1 questions, the right ones counted.
      final ratios = resultRatios(tester);
      expect(ratios, expectedRatios(picks));
      final totals = [for (final r in ratios) int.parse(r.split(' / ')[1])];
      expect(totals, [3, 3, 3, 4, 3, 3, 1]);
      final rights = [for (final r in ratios) int.parse(r.split(' / ')[0])];
      expect(rights.fold<int>(0, (a, b) => a + b), 16);

      // The 4 failed questions are listed.
      expect(failedRowNumbers(tester), wrong);

      // "Repasar los 4 fallos" opens a review of exactly those 4.
      await tester.tapText(T.repasarFallos(4));
      await tester.waitFor(find.text(T.ratio(1, 4)), reason: 'review of 4');
      final expectedIds = [
        for (final p in picks)
          if (p.outcome == false) p.question.id,
      ];
      final reviewed = await practiceRun(app, [true, true, true, true]);
      expect([for (final q in reviewed) q.id], expectedIds);
      await tester.tapText(T.terminar);
      await tester.waitFor(find.text(T.sesionTerminada));
      expect(find.text(T.ratio(4, 4)), findsOneWidget);

      // (one right answer is not enough to clear them).
      await tester.tapText(T.volverAlInicio);
      await waitHome(app);
      await tester.waitFor(find.text(T.fallosPendientes(4)));

      // The mock row: finished, 16 correct.
      final mocks = await app.container.read(mockRepositoryProvider).history(5);
      expect(mocks.length, 1);
      expect(
        (await app.container.read(attemptRepositoryProvider).all()).length,
        24,
        reason: '20 mock answers + 4 review answers',
      );
    },
  );

  qaScenario('simulacro_suspenso', '15 aciertos: NO APTO', (tester) async {
    final app = await launchApp(tester);
    await startMockFromHome(app);
    const wrong = {2, 5, 8, 11, 14};
    final picks = await playMock(app, wrong: wrong);
    await submitMock(app, body: T.entregarTodas);

    expect(find.text(T.noApto), findsOneWidget);
    expect(find.text(T.apto), findsNothing);
    expect(ringScore('15'), findsOneWidget);
    expect(find.text(T.deVeinte), findsOneWidget);
    expect(find.text(T.marcaAprobado), findsOneWidget);
    expect(resultRatios(tester), expectedRatios(picks));
    expect(failedRowNumbers(tester), wrong);
    expect(find.text(T.repasarFallos(5)), findsOneWidget);
  });

  qaScenario(
    'simulacro_en_blanco',
    'entregar con 19 en blanco: aviso, NO APTO y las en blanco se listan',
    (tester) async {
      final app = await launchApp(tester);
      await startMockFromHome(app);
      final picks = await playMock(
        app,
        blank: {for (var n = 2; n <= 20; n++) n},
      );
      // The dialog says how many are unanswered.
      await submitMock(app, body: T.entregarSinResponder(19));

      expect(find.text(T.noApto), findsOneWidget);
      expect(ringScore('1'), findsOneWidget);
      expect(find.text(T.deVeinte), findsOneWidget);
      expect(resultRatios(tester), expectedRatios(picks));
      expect(failedRowNumbers(tester), {for (var n = 2; n <= 20; n++) n});
      expect(find.text(T.sinResponder), findsNWidgets(19));
      expect(find.text(T.repasarFallos(19)), findsOneWidget);

      // A blank question opens a read-only review that says so.
      await tester.tapFinder(failedRow(2), reason: 'row of question 2');
      await tester.waitFor(find.text(T.revision));
      expect(find.text(T.sinResponder), findsOneWidget);
      expect(find.text(T.respuestaCorrecta), findsOneWidget);
      await tester.systemBack();
      await tester.waitFor(find.text(T.deVeinte));
    },
  );

  qaScenario(
    'simulacro_tiempo',
    'el resultado del simulacro dice el tiempo empleado',
    (tester) async {
      final app = await launchApp(tester);
      await startMockFromHome(app);
      // One answer and the rest in blank: the result shows the elapsed time
      // anyway.
      await answerMock(app, 1, outcome: true);
      await submitMock(app, body: T.entregarSinResponder(19));
      expect(find.text(T.noApto), findsOneWidget);

      // The time shown is the one stored with the mock: from the start to the
      // hand-in.
      final record =
          (await app.container.read(mockRepositoryProvider).history(5)).single;
      final elapsed = record.finishedAt!.difference(record.startedAt);
      expect(elapsed, greaterThan(Duration.zero));
      expect(
        find.text(
          '${T.tiempoEmpleado} ${elapsed.inMinutes} min '
          '${elapsed.inSeconds.remainder(60)} s',
        ),
        findsOneWidget,
      );
    },
  );

  qaScenario(
    'salir_del_simulacro',
    'salir pide confirmación; se retoma el simulacro con sus respuestas',
    (tester) async {
      final app = await launchApp(tester);
      await startMockFromHome(app);
      final pick = await answerMock(app, 1, outcome: true);
      final picked = pick.question.answer;

      // The close button asks first; "Seguir" stays.
      await askToLeaveMock(app);
      expect(find.textContaining(T.podrasRetomar), findsOneWidget);
      expect(find.text(T.seguir), findsOneWidget);
      await tester.tapText(T.seguir);
      await tester.waitGone(find.byType(AlertDialog));
      expect(find.text(T.ratio(1, 20)), findsOneWidget);

      // The system back button asks too.
      await tester.systemBack();
      await tester.waitFor(find.text(T.salirTitulo));
      await confirmLeaveMock(app);

      // Left open: it counts as started, nothing was recorded as answered,
      // and Inicio offers to continue instead of the purchase screen.
      expect(find.text(T.simulacroSinEntregar), findsOneWidget);
      expect(
        await app.container.read(mockRepositoryProvider).startedCount(),
        1,
      );
      expect(
        await app.container.read(attemptRepositoryProvider).all(),
        isEmpty,
        reason: 'an open mock stores no attempts',
      );
      expect(find.text(T.fallosPendientes(0)), findsOneWidget);

      // Simulacro: "Continuar simulacro" reopens it with its answer.
      await tester.tapText(T.simulacro);
      await tester.waitFor(find.text(T.continuarSimulacro));
      expect(find.textContaining('1 de 20 respondidas'), findsOneWidget);
      await tester.tapText(T.continuarSimulacro);
      await tester.waitFor(find.text(T.ratio(1, 20)));
      expect(
        optionStates()[picked],
        OptionState.selected,
        reason: 'question 1 keeps its answer',
      );
      expect(
        await app.container.read(mockRepositoryProvider).startedCount(),
        1,
        reason: 'resuming is not a second mock',
      );

      // Starting another exam asks before replacing the open one.
      await askToLeaveMock(app);
      await confirmLeaveMock(app);
      await tester.tapText(T.simulacro);
      await tester.waitFor(find.text(T.empezarOtro));
      await tester.tapText(T.empezarOtro);
      await tester.waitFor(find.text('¿Empezar otro simulacro?'));
    },
  );
}
