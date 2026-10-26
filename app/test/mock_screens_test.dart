import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/progress_header.dart';
import 'package:apto_armas/core/widgets/round_icon_button.dart';
import 'package:apto_armas/core/widgets/score_ring.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/mock_constants.dart';
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/bank_content_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

const _temaTitles = [
  'Funcionamiento y seguridad',
  'Categorías de armas',
  'Circulación, revista y transferencia',
  'Documentación y licencias, Tarjeta Europea',
  'Régimen sancionador',
  'Reparación, prueba y depósito',
  'Armas de colección, definiciones, historia, calibres y munición',
];

/// The question on screen in mock [id].
Question _current(WidgetTester tester, int id) =>
    containerOf(tester)
        .read(mockControllerProvider(id))
        .requireValue
        .session
        .currentQuestion;

/// From Inicio: Simulacro -> Empezar. Returns the mock id.
Future<int> _startMock(WidgetTester tester, {bool timed = false}) async {
  await pushRoute(tester, '/simulacro');
  // The switch is on by default: set it to what the test wants.
  if (tester.widget<Switch>(find.byType(Switch)).value != timed) {
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Empezar'));
  await tester.pumpAndSettle();
  final match = RegExp(r'^/simulacro/(\d+)$').firstMatch(locationOf(tester));
  expect(match, isNotNull, reason: 'now on the running mock');
  return int.parse(match!.group(1)!);
}

/// Answers every question with its official answer for the first [right]
/// ones and a wrong option for the next [wrong] ones, using "Siguiente".
Future<void> _answerAll(
  WidgetTester tester,
  int id, {
  required int right,
  required int wrong,
}) async {
  for (var i = 0; i < right + wrong; i++) {
    final q = _current(tester, id);
    await tapOption(tester, i < right ? q.answer : wrongOption(q));
    if (i < 19) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
  }
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Entregar'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testScreen('intro explains the exam, timer on by default', (tester) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/simulacro');
    expect(find.textContaining('20 preguntas de test'), findsOneWidget);
    expect(find.textContaining('Se aprueba con 16 aciertos'), findsOneWidget);
    expect(
      find.textContaining('Cronómetro orientativo (20 min)'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Empezar'), findsOneWidget);
  });

  testScreen('the timer choice is remembered between visits', (tester) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/simulacro');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(
      await containerOf(tester)
          .read(settingsDaoProvider)
          .get(MockSettingKeys.timerEnabled),
      '0',
    );

    // Leave and come back: still off, not reset to the default.
    routerOf(tester).go('/');
    await tester.pumpAndSettle();
    await pushRoute(tester, '/simulacro');
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    // Turn it on again: that is remembered too.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    routerOf(tester).go('/');
    await tester.pumpAndSettle();
    await pushRoute(tester, '/simulacro');
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testScreen(
    'start -> 20 questions, no feedback, navigator, 16 right is APTO',
    (tester) async {
      var now = kTestNow;
      await pumpFullApp(tester, clock: () => now);
      final id = await _startMock(tester);

      expect(find.byType(ProgressHeader), findsOneWidget);
      expect(find.text('1 / 20'), findsOneWidget);
      expect(find.byType(OptionCard), findsNWidgets(3));
      expect(find.text('Cronómetro'), findsNothing);
      expect(find.textContaining('Quedan'), findsNothing);

      // Picking shows "selected", never right / wrong, and can be changed.
      final q = _current(tester, id);
      await tapOption(tester, wrongOption(q));
      expect(optionStates(tester)[wrongOption(q)], OptionState.selected);
      expect(
        optionStates(tester).where((s) => s != OptionState.idle),
        hasLength(1),
      );
      await tapOption(tester, q.answer);
      expect(optionStates(tester)[q.answer], OptionState.selected);
      expect(optionStates(tester)[wrongOption(q)], OptionState.idle);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);

      // Jump with the navigator: 20 numbered cells, question 1 answered.
      await tester.tap(find.text('Preguntas'));
      await tester.pumpAndSettle();
      expect(find.byType(MockNavigator), findsOneWidget);
      final nav = tester.widget<MockNavigator>(find.byType(MockNavigator));
      expect(nav.count, 20);
      expect(nav.current, 0);
      expect(nav.answered, {0});
      await tester.tap(
        find.descendant(
          of: find.byType(MockNavigator),
          matching: find.text('12'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12 / 20'), findsOneWidget);
      expect(find.byType(MockNavigator), findsNothing);

      // Previous goes back one.
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('11 / 20'), findsOneWidget);

      // Back to the start; answer 16 right (question 1 already is), 4 blank.
      await tester.tap(find.text('Preguntas'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MockNavigator),
          matching: find.text('2'),
        ),
      );
      await tester.pumpAndSettle();
      // Questions 2..16 right.
      for (var i = 1; i < 16; i++) {
        final cur = _current(tester, id);
        await tapOption(tester, cur.answer);
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }
      expect(find.text('17 / 20'), findsOneWidget);

      // Entregar: the dialog says how many are blank (4).
      await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Entregar el simulacro?'), findsOneWidget);
      expect(
        find.text('Te quedan 4 preguntas sin responder y contarán como fallo.'),
        findsOneWidget,
      );
      // "Seguir" goes back to the exam.
      await tester.tap(find.text('Seguir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(locationOf(tester), '/simulacro/$id');

      now = kTestNow.add(const Duration(minutes: 14, seconds: 32));
      await _submit(tester);

      // Result: APTO with a check icon, 16 / 20, one row per tema.
      expect(locationOf(tester), '/simulacro/$id/resultado');
      expect(find.text('APTO'), findsOneWidget);
      expect(find.text('NO APTO'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('de 20'), findsOneWidget);
      final elapsed = find.text('Tiempo empleado: 14 min 32 s');
      expect(elapsed, findsOneWidget);
      expect(
        tester.widget<Text>(elapsed).style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      expect(
        find.text('La marca indica el aprobado: 16 aciertos.'),
        findsOneWidget,
      );
      // The ring carries a tick at the pass mark (16 / 20).
      final ring =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(ScoreRing),
                      matching: find.byWidgetPredicate(
                        (w) =>
                            w is CustomPaint && w.painter is ScoreRingPainter,
                      ),
                    ),
                  )
                  .painter!
              as ScoreRingPainter;
      expect(ring.passMark, 0.8);
      expect(ring.value, 0.8);
      expect(ring.color, AptoColors.light.correct);
      // One row per tema (number, title, bar, hits).
      for (final title in _temaTitles) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      // Failed list: the 4 blank ones, tap one for a read-only review.
      expect(find.text('Sin responder'), findsNWidgets(4));
      await tester.ensureVisible(find.text('PREGUNTAS'));
      final firstFailed = find.textContaining('17. ');
      await tester.ensureVisible(firstFailed);
      await tester.tap(firstFailed);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/simulacro/$id/revision/16?falladas=1');
      final failedQuestion = (await containerOf(
        tester,
      ).read(mockOutcomeProvider(id).future))!.questions[16];
      expect(find.text(failedQuestion.stem), findsOneWidget);
      expectBankContent(failedQuestion);
      expect(find.text('Sin responder'), findsOneWidget);
      expect(
        optionStates(tester)[failedQuestion.answer],
        OptionState.revealedCorrect,
      );
      // Options are read-only.
      await tester.tap(find.byType(OptionCard).first);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/simulacro/$id/revision/16?falladas=1');

      // The attempts of the mock are stored.
      final attempts = await containerOf(tester)
          .read(attemptRepositoryProvider)
          .all();
      expect(attempts.where((a) => a.mode == AttemptMode.mock), hasLength(20));
      expect(attempts.where((a) => a.correct), hasLength(16));
    },
  );

  testScreen('15 right is NO APTO, and the failed questions are listed', (
    tester,
  ) async {
    var now = kTestNow;
    await pumpFullApp(tester, clock: () => now);
    final id = await _startMock(tester);
    await _answerAll(tester, id, right: 15, wrong: 5);
    now = kTestNow.add(const Duration(minutes: 21, seconds: 7));
    await _submit(tester);

    expect(find.text('Tiempo empleado: 21 min 7 s'), findsOneWidget);
    expect(find.text('NO APTO'), findsOneWidget);
    expect(find.text('APTO'), findsNothing);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    // The verdict icon uses the icon token, the text its text colour.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.cancel_rounded)).color,
      AptoColors.light.incorrect,
    );
    expect(
      tester.widget<Text>(find.text('NO APTO')).style!.color,
      AptoColors.light.incorrectText,
    );
    // Close sits top-left, like on the question and the exam.
    final close = tester.getRect(find.byType(RoundIconButton));
    expect(
      close.center.dx,
      lessThan(tester.getRect(find.byType(Scaffold)).center.dx),
    );
    expect(close.top, Sp.s + tester.view.padding.top);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('de 20'), findsOneWidget);
    // 5 wrong answers listed with the letter picked.
    expect(find.textContaining('Tu respuesta: '), findsNWidgets(5));
    expect(find.text('Sin responder'), findsNothing);

    // "Repasar los 5 fallos" reviews the 5 failures of this mock.
    final button = find.text('Repasar los 5 fallos');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/simulacro/$id/repasar');
    expect(find.text('1 / 5'), findsOneWidget);

    // Inicio is still underneath: back, back, and it shows the 5 mistakes.
    routerOf(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Volver al inicio'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/');
    expect(find.text('5 fallos pendientes'), findsOneWidget);
  });

  testScreen(
    '"Repasar los 4 fallos" reviews only the 3 wrong + 1 blank of the mock',
    (tester) async {
      await pumpFullApp(tester);
      final id = await _startMock(tester);
      // An older failure elsewhere: it must not leak into the mock's review.
      final bank = await bankOf(tester);
      final mockIds = <String>[];
      final expected = <String>[];
      for (var i = 0; i < 20; i++) {
        final q = _current(tester, id);
        mockIds.add(q.id);
        if (i == 3) {
          expected.add(q.id); // left blank
        } else {
          final wrong = i < 3;
          if (wrong) expected.add(q.id);
          await tapOption(tester, wrong ? wrongOption(q) : q.answer);
        }
        if (i < 19) {
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
        }
      }
      await _submit(tester);
      expect(find.text('16'), findsOneWidget);
      expect(find.text('Sin responder'), findsOneWidget);

      // Another question failed outside the mock: pending in Fallos too.
      final stray = bank.firstWhere((q) => !mockIds.contains(q.id));
      await containerOf(tester)
          .read(studyServiceProvider)
          .recordAnswers([attemptOn(stray, correct: false)]);
      await tester.pumpAndSettle();

      final button = find.text('Repasar los 4 fallos');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/simulacro/$id/repasar');
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('FALLOS DEL SIMULACRO'), findsOneWidget);

      final session = containerOf(tester)
          .read(practiceControllerProvider(MockMistakesPractice(id)))
          .requireValue
          .session!;
      expect([for (final q in session.questions) q.id], expected);
      expect(session.questions.map((q) => q.id), isNot(contains(stray.id)));
    },
  );

  testScreen('Entregar with everything answered says so', (tester) async {
    await pumpFullApp(tester);
    final id = await _startMock(tester);
    await _answerAll(tester, id, right: 20, wrong: 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Entregar'));
    await tester.pumpAndSettle();
    expect(find.text('Has respondido todas las preguntas.'), findsOneWidget);
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
  });

  testScreen('answers are written to the database as they change', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final id = await _startMock(tester);
    final q = _current(tester, id);
    await tapOption(tester, q.answer);
    await containerOf(tester)
        .read(mockControllerProvider(id).notifier)
        .pendingSaves;
    final record = (await containerOf(tester)
        .read(mockRepositoryProvider)
        .byId(id))!;
    expect(record.answers.first, q.answer);
    expect(record.isFinished, isFalse);
  });

  testScreen('back asks before abandoning the exam', (tester) async {
    await pumpFullApp(tester);
    final id = await _startMock(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('¿Salir del simulacro?'), findsOneWidget);
    await tester.tap(find.text('Seguir'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/simulacro/$id');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/');
    // Nothing was handed in.
    expect(
      await containerOf(tester).read(attemptRepositoryProvider).all(),
      isEmpty,
    );
  });

  testScreen(
    'timed mock: countdown, then "Tiempo orientativo agotado" without submitting',
    (tester) async {
      var now = kTestNow;
      await pumpFullApp(tester, clock: () => now);
      final id = await _startMock(tester, timed: true);
      expect(find.text('Quedan 20:00'), findsOneWidget);

      now = kTestNow.add(const Duration(minutes: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Quedan 15:00'), findsOneWidget);

      now = kTestNow.add(const Duration(minutes: 20, seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Tiempo orientativo agotado'), findsOneWidget);
      expect(find.textContaining('Quedan'), findsNothing);
      // Still in the exam, still able to answer and hand in.
      expect(locationOf(tester), '/simulacro/$id');
      await tapOption(tester, 0);
      expect(optionStates(tester)[0], OptionState.selected);
      expect(find.widgetWithText(FilledButton, 'Entregar'), findsOneWidget);
    },
  );

  testScreen('opening a handed-in mock shows its result', (tester) async {
    await pumpFullApp(tester);
    final id = await _startMock(tester);
    await _answerAll(tester, id, right: 16, wrong: 4);
    await _submit(tester);
    expect(find.text('APTO'), findsOneWidget);

    routerOf(tester).go('/simulacro/$id');
    await tester.pumpAndSettle();
    expect(locationOf(tester), '/simulacro/$id/resultado');
    expect(find.text('16'), findsOneWidget);
    expect(find.text('de 20'), findsOneWidget);
  });

  testScreen('resumed mock includes time away and keeps its delivery time', (
    tester,
  ) async {
    var now = kTestNow;
    await pumpFullApp(tester, clock: () => now);
    final id = await _startMock(tester);
    await tapOption(tester, 0);
    final container = containerOf(tester);
    await container.read(mockControllerProvider(id).notifier).pendingSaves;
    await openRoute(tester, '/');
    container.invalidate(mockControllerProvider(id));

    // Rebuild the running session from storage after a day away.
    now = kTestNow.add(const Duration(days: 1, minutes: 21, seconds: 7));
    await pushRoute(tester, '/simulacro/$id');
    expect(
      container.read(mockControllerProvider(id)).requireValue.startedAt,
      kTestNow,
    );
    await _submit(tester);
    expect(find.text('Tiempo empleado: 1461 min 7 s'), findsOneWidget);

    await openRoute(tester, '/');
    container.invalidate(mockOutcomeProvider(id));
    now = now.add(const Duration(hours: 2));
    await pushRoute(tester, '/simulacro/$id/resultado');
    expect(find.text('Tiempo empleado: 1461 min 7 s'), findsOneWidget);
  });

  testScreen('result without delivery time does not show elapsed time', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final id = await _startMock(tester);
    await openRoute(tester, '/simulacro/$id/resultado');
    expect(find.text('Este simulacro no se ha entregado.'), findsOneWidget);
    expect(find.textContaining('Tiempo empleado:'), findsNothing);
  });

  testScreen('a mock that does not exist shows a retry state, not a crash', (
    tester,
  ) async {
    await pumpFullApp(tester);
    await pushRoute(tester, '/simulacro/9999');
    expect(find.text('No se han podido cargar los datos'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await pushRoute(tester, '/simulacro/9999/resultado');
    expect(find.text('Este simulacro no se ha entregado.'), findsOneWidget);
  });
}
