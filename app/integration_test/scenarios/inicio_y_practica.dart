import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/score_ring.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:apto_armas/features/srs/application/srs_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';
import '../support/qa_ui.dart';

/// A launcher that records the links instead of opening them: the scenario
/// must not fire a mail intent on the device.
class _RecordingLauncher implements UrlLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

/// Texts of the "Cifras y plazos" mode and the "Pregunta del día" card.
const _cifrasTitle = 'Cifras y plazos';

const _diariaOverline = 'PREGUNTA DEL DÍA';

const _responder = 'Responder';

const _respondidaHoy = 'Respondida hoy';

const _rachaUnDia = 'Racha de 1 día';

void registerInicioYPractica() {
  qaScenario(
    'cifras_y_plazos',
    'Cifras y plazos: abre todas las preguntas con cifra',
    (tester) async {
      final app = await launchApp(tester);
      final bank = await app.container.read(questionsProvider.future);
      final figures = bank.where((q) => q.isFigures).toList();
      expect(figures.length, greaterThan(60));

      expect(lockIcons(), 0, reason: 'all content is open');
      await tester.tapText(_cifrasTitle);
      await tester.waitFor(
        find.text(T.ratio(1, figures.length)),
        reason: 'the figures session',
      );
      expect(find.text(_cifrasTitle.toUpperCase()), findsOneWidget);

      // The question on screen is one of the flagged ones; a wrong answer is
      // stored in practice mode and shows the usual feedback.
      final q = await answerPractice(app, correct: false);
      expect(figures.map((f) => f.id), contains(q.id));
      expect(find.text(T.incorrecto), findsOneWidget);
      final attempts = await app.container
          .read(attemptRepositoryProvider)
          .all();
      expect(attempts.single.mode, AttemptMode.practice);
      expect(attempts.single.questionId, q.id);

      await closePracticeToHome(app);
      await tester.waitFor(find.text(T.fallosPendientes(1)));
      tester.expectNoException('cifras_y_plazos');
    },
  );

  qaScenario(
    'practica_avisanos',
    '«¿Ves un error? Avísanos» aparece tras responder y abre un mailto',
    (tester) async {
      final launcher = _RecordingLauncher();
      final app = await launchApp(
        tester,
        overrides: [
          settingsLinksProvider.overrideWithValue(
            const SettingsLinks(supportEmail: 'soporte@ejemplo.es'),
          ),
          urlLauncherProvider.overrideWithValue(launcher),
        ],
      );
      await openTema(app, 1);
      await tester.waitFor(find.text(T.ratio(1, 68)), reason: 'question 1/68');
      // Not before answering.
      expect(find.text('¿Ves un error? Avísanos'), findsNothing);

      final q = await answerPractice(app, correct: false);
      await tester.ensureVisible(find.text('¿Ves un error? Avísanos'));
      await tester.pumpFor(const Duration(milliseconds: 300));
      expect(find.text('¿Ves un error? Avísanos'), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

      await tester.tapText('¿Ves un error? Avísanos');
      await tester.pumpFor(const Duration(milliseconds: 300));
      expect(launcher.opened, hasLength(1));
      expect(launcher.opened.single.scheme, 'mailto');
      expect(launcher.opened.single.toString(), contains(q.id));
      tester.expectNoException('practica_avisanos');
    },
  );

  qaScenario(
    'arranque',
    'el arranque importa las 423 preguntas y Inicio muestra todo',
    (tester) async {
      final app = await launchApp(tester);

      // The bank imported by the bootstrap: 423 questions, 68/67/66/70/66/64/22.
      final questions = await app.container.read(questionsProvider.future);
      expect(questions.length, 423);
      for (var tema = 1; tema <= 7; tema++) {
        expect(
          questions.where((q) => q.tema == tema).length,
          app.bank.countOfTema(tema),
          reason: 'questions of tema $tema in the database',
        );
      }
      expect(
        [for (var t = 1; t <= 7; t++) app.bank.countOfTema(t)],
        [68, 67, 66, 70, 66, 64, 22],
      );

      // Inicio.
      expect(find.byType(ScoreRing), findsOneWidget);
      expect(find.text(T.continuar), findsOneWidget);
      expect(find.text(T.continuarCount(15)), findsOneWidget);
      expect(find.text(T.simulacro), findsOneWidget);
      expect(find.text(T.simulacroLibre), findsOneWidget);
      expect(find.text(T.fallos), findsOneWidget);
      expect(find.text(T.fallosPendientes(0)), findsOneWidget);
      expect(find.text(T.temasOverline), findsOneWidget);
      expect(find.byTooltip(T.ajustes), findsOneWidget);
      // Every study mode is available from a fresh installation.
      expect(lockIcons(), 0);
      expect(find.textContaining(T.legal), findsOneWidget);
      expect(find.text(T.edicion), findsOneWidget);
      tester.expectNoException('arranque');
    },
  );

  qaScenario(
    'practica_tema1',
    '3 respuestas (1 fallo, 2 aciertos): feedback, explicacion y Fallos',
    (tester) async {
      final app = await launchApp(tester);
      await openTema(app, 1);
      await tester.waitFor(find.text(T.ratio(1, 68)), reason: 'question 1/68');

      // 1) wrong.
      final q1 = await answerPractice(app, correct: false);
      expect(find.text(T.incorrecto), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsWidgets);
      expect(find.text(T.respuestaCorrecta), findsOneWidget);
      expect(find.text(T.explicacion), findsOneWidget);
      expect(find.text(T.siguiente), findsOneWidget);
      final states = optionStates();
      expect(states[q1.wrongOption], OptionState.incorrect);
      expect(states[q1.answer], OptionState.revealedCorrect);
      expect(
        states.where((s) => s == OptionState.idle).length,
        1,
        reason: 'the third option stays neutral',
      );

      // 2) right.
      await tester.tapText(T.siguiente);
      await currentQuestion(app, notId: q1.id);
      await tester.waitFor(find.text(T.ratio(2, 68)));
      final q2 = await answerPractice(app, correct: true);
      expect(find.text(T.correcto), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      expect(optionStates()[q2.answer], OptionState.correct);

      // 3) right.
      await tester.tapText(T.siguiente);
      await currentQuestion(app, notId: q2.id);
      final q3 = await answerPractice(app, correct: true);
      expect(find.text(T.correcto), findsOneWidget);

      // What was stored.
      final attempts = await app.container
          .read(attemptRepositoryProvider)
          .all();
      expect(attempts.length, 3);
      final byId = {for (final a in attempts) a.questionId: a};
      expect(byId[q1.id]!.correct, isFalse);
      expect(byId[q2.id]!.correct, isTrue);
      expect(byId[q3.id]!.correct, isTrue);
      expect(attempts.every((a) => a.mode == AttemptMode.practice), isTrue);

      // Back on Inicio: one mistake, shown on the tile and on tema 1.
      await closePracticeToHome(app);
      await tester.waitFor(
        find.text(T.fallosPendientes(1)),
        reason: 'one pending mistake on the Fallos tile',
      );
      await tester.waitFor(
        find.descendant(of: temaCard(1), matching: find.text(T.temaFallos(1))),
        reason: 'tema 1 shows "1 fallo"',
      );
      expect(
        find.descendant(of: temaCard(2), matching: find.text(T.temaFallos(1))),
        findsNothing,
      );
    },
  );

  qaScenario(
    'persistencia_tras_reinicio',
    'el progreso sobrevive a cerrar y abrir la app',
    (tester) async {
      final app = await launchApp(tester);
      await openTema(app, 1);
      await practiceRun(app, [false, true]);
      await closePracticeToHome(app);
      await tester.waitFor(find.text(T.fallosPendientes(1)));

      await app.restart();
      await tester.waitFor(
        find.text(T.fallosPendientes(1)),
        reason: 'the mistake is still there after the restart',
      );
      // 1 due + 15 - 2 new.
      await tester.waitFor(find.text(T.continuarCount(14)));
      final attempts = await app.container
          .read(attemptRepositoryProvider)
          .all();
      expect(attempts.length, 2);
      // The bank is not imported twice.
      final questions = await app.container.read(questionsProvider.future);
      expect(questions.length, 423);
    },
  );

  qaScenario(
    'fallos_y_revision',
    'lista de fallos por tema, Repasar todos y dos aciertos seguidos los quitan',
    (tester) async {
      // A paying user, so tema 2 can be practised too.
      final app = await launchApp(tester);
      await openTema(app, 1);
      final tema1 = await practiceRun(app, [false, false]);
      await closePracticeToHome(app);
      await openTema(app, 2);
      final tema2 = await practiceRun(app, [false]);
      await closePracticeToHome(app);

      await tester.waitFor(find.text(T.fallosPendientes(3)));
      await tester.tapText(T.fallos);
      await tester.waitFor(
        find.text(T.falladaUnaVez),
        count: 3,
        reason: 'three mistakes listed',
      );
      for (final q in [...tema1, ...tema2]) {
        expect(tester.hasText(q.stem), isTrue, reason: 'stem of ${q.id}');
      }

      // Filter by tema.
      Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
      await tester.tapFinder(chip('Tema 1'));
      await tester.waitFor(find.text(T.falladaUnaVez), count: 2);
      await tester.tapFinder(chip('Tema 2'));
      await tester.waitFor(find.text(T.falladaUnaVez), count: 1);
      await tester.tapFinder(chip('Tema 3'));
      await tester.waitFor(find.text(T.sinFallosTitulo));
      await tester.tapFinder(chip('Tema 1'));
      await tester.waitFor(find.text(T.falladaUnaVez), count: 2);

      // Review only tema 1: both right (1st correct answer after the miss).
      await tester.tapText(T.repasarTodos);
      await tester.waitFor(find.text(T.ratio(1, 2)), reason: 'review of 2');
      final pass1 = await practiceRun(app, [true, true]);
      expect({for (final q in pass1) q.id}, {for (final q in tema1) q.id});
      await tester.tapText(T.terminar);
      await tester.waitFor(find.text(T.sesionTerminada));
      expect(find.text(T.ratio(2, 2)), findsOneWidget);
      await tester.tapText(T.volverAlInicio);
      await waitHome(app);

      // One right answer is not enough: still 3 pending.
      await tester.waitFor(find.text(T.fallosPendientes(3)));

      // Review everything: the 2 tema 1 questions get their second right
      // answer and leave the list; tema 2 only has its first.
      await tester.tapText(T.fallos);
      await tester.waitFor(find.text(T.falladaUnaVez), count: 3);
      await tester.tapText(T.repasarTodos);
      await tester.waitFor(find.text(T.ratio(1, 3)), reason: 'review of 3');
      final pass2 = await practiceRun(app, [true, true, true]);
      expect(
        {for (final q in pass2) q.id},
        {
          for (final q in [...tema1, ...tema2]) q.id,
        },
      );
      await tester.tapText(T.terminar);
      await tester.waitFor(find.text(T.sesionTerminada));
      await tester.tapText(T.volverAlInicio);
      await waitHome(app);
      await tester.waitFor(find.text(T.fallosPendientes(1)));

      // Last one: second right answer, the list empties.
      await tester.tapText(T.fallos);
      await tester.waitFor(find.text(T.falladaUnaVez), count: 1);
      await tester.tapText(T.repasarTodos);
      await tester.waitFor(find.text(T.ratio(1, 1)));
      final pass3 = await practiceRun(app, [true]);
      expect(pass3.single.id, tema2.single.id);
      await tester.tapText(T.terminar);
      await tester.waitFor(find.text(T.sesionTerminada));
      await tester.tapText(T.volverAlInicio);
      await waitHome(app);
      await tester.waitFor(find.text(T.fallosPendientes(0)));
      await tester.tapText(T.fallos);
      await tester.waitFor(find.text(T.sinFallosTitulo));
    },
  );

  qaScenario(
    'pregunta_del_dia',
    'Pregunta del día: se responde, cuenta la racha y sobrevive al reinicio',
    (tester) async {
      final app = await launchApp(tester);
      await tester.waitFor(find.text(_diariaOverline), reason: 'the card');
      expect(find.text(_rachaUnDia), findsNothing);

      await tester.tapText(_responder);
      await tester.waitFor(find.text(T.ratio(1, 1)), reason: 'one question');
      final q = await answerPractice(app, correct: true);
      expect(q.tema, inInclusiveRange(1, 7));
      expect(find.text(T.correcto), findsOneWidget);
      // One question: "Terminar" goes straight back to Inicio.
      await tester.tapText(T.terminar);
      await waitHome(app);
      await tester.waitFor(find.text(_respondidaHoy));
      await tester.waitFor(find.text(_rachaUnDia));
      expect(find.text(_responder), findsNothing);

      await app.restart();
      await tester.waitFor(
        find.text(_respondidaHoy),
        reason: 'answered today, still, after the restart',
      );
      expect(find.text(_rachaUnDia), findsOneWidget);
      tester.expectNoException('pregunta_del_dia');
    },
  );

  qaScenario(
    'repaso_del_dia',
    'Continuar: la pregunta fallada vuelve primero y se respeta la cuota',
    (tester) async {
      final app = await launchApp(tester);
      await openTema(app, 1);
      final run = await practiceRun(app, [false, true, true]);
      await closePracticeToHome(app);

      // 1 due (the miss, box 1 = today) + 15 - 3 new questions.
      await tester.waitFor(
        find.text(T.continuarCount(13)),
        reason: 'the queue is 1 due + 12 new',
      );
      await tester.tapText(T.continuar);
      await tester.waitFor(find.text(T.ratio(1, 13)), reason: 'daily session');

      // The failed question comes back first.
      final first = await currentQuestion(app);
      expect(first.id, run.first.id);
      await answerPractice(app, correct: true);
      expect(find.text(T.correcto), findsOneWidget);

      // Then new questions from the bank, never one seen today.
      await tester.tapText(T.siguiente);
      final second = await currentQuestion(app, notId: first.id);
      expect(second.tema, 1);
      expect({for (final q in run) q.id}.contains(second.id), isFalse);

      // Stored with the srs mode.
      final attempts = await app.container
          .read(attemptRepositoryProvider)
          .all();
      expect(attempts.length, 4);
      final srs = attempts.where((a) => a.mode == AttemptMode.srs).toList();
      expect(srs.length, 1);
      expect(srs.single.questionId, first.id);
      expect(srs.single.correct, isTrue);

      // The queue shrinks: the repeated miss is no longer due.
      await closePracticeToHome(app);
      await tester.waitFor(find.text(T.continuarCount(12)));
      // Right once after a miss: still in Fallos (needs two in a row).
      expect(find.text(T.fallosPendientes(1)), findsOneWidget);
      final queue = await app.container.read(dailyQueueProvider.future);
      expect(queue.length, 12);
      expect(
        queue.every(
          (id) => app.bank.byId(id).tema >= 1 && app.bank.byId(id).tema <= 7,
        ),
        isTrue,
      );
    },
  );
}
