import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';
import '../support/qa_ui.dart';

/// The wait after a tap of the card buttons: the card is rebuilt right away,
/// the wait is only there to let the frame settle.
const _tapWait = Duration(milliseconds: 150);

/// The questions of the bank flagged as figures ("cifras"), the deck of the
/// cards.
Future<List<Question>> _figuresQuestions(QaApp app) async {
  final questions = await app.container.read(questionsProvider.future);
  return questions.where((q) => q.isFigures).toList();
}

/// The stem of the card on screen (the only text of the bank it shows).
String? _stemOnScreen(QaApp app, List<Question> figures) {
  final stems = {for (final q in figures) q.stem};
  for (final text in app.tester.visibleTexts()) {
    if (stems.contains(text)) return text;
  }
  return null;
}

/// The revealed answer ("A. text") is the official one of the card.
void _expectOfficialAnswer(QaApp app, List<Question> figures, String stem) {
  final line = app.tester.visibleTexts().firstWhere(
    (text) => RegExp(r'^[A-C]\. ').hasMatch(text),
    orElse: () => '',
  );
  expect(line, isNotEmpty, reason: 'the answer is revealed behind the card');
  final candidates = figures.where((q) => q.stem == stem).toList();
  expect(candidates, isNotEmpty, reason: 'the stem on screen is a figures one');
  expect(
    candidates.any(
      (q) =>
          line ==
          '${String.fromCharCode(65 + q.answer)}. ${q.options[q.answer]}',
    ),
    isTrue,
    reason: 'the revealed answer is the official one of "$stem"',
  );
}

/// Reveals the card on screen and answers it: "La sabía" or "Repasar otra vez".
/// Waits for the next card (or for the summary of the round, the only screen
/// with the "Volver" button).
Future<void> _answerCard(QaApp app, {required bool known}) async {
  final tester = app.tester;
  await tester.tapText(T.verRespuesta, wait: _tapWait);
  await tester.waitFor(find.text(T.laSabia), reason: 'the revealed card');
  await tester.tapText(known ? T.laSabia : T.repasarOtraVez, wait: _tapWait);
  await tester.waitUntil(
    () =>
        find.text(T.verRespuesta).evaluate().isNotEmpty ||
        find.text(T.volver).evaluate().isNotEmpty,
    reason: 'the next card or the summary',
  );
}

/// The tile of Inicio that opens the cards.
Finder _tarjetasTile() => find.widgetWithText(ActionCard, T.tarjetasTitulo);

/// "Tarjetas de cifras" (`/cifras/tarjetas`): the tile of Inicio, the round
void registerCifrasTarjetas() {
  qaScenario(
    'cifras_tarjetas_completa',
    'Tarjetas de cifras con la acceso completo: ver la respuesta, «La sabía», '
        '«Repasar otra vez», el resumen y repetir',
    (tester) async {
      final app = await launchApp(tester);
      await waitHome(app);

      final figures = await _figuresQuestions(app);
      expect(figures.length, greaterThan(60), reason: 'the bank has figures');

      // The tile of Inicio: how many cards, no lock.
      final tile = _tarjetasTile();
      expect(tile, findsOneWidget);
      expect(
        find.descendant(
          of: tile,
          matching: find.text(T.tarjetasSubtitulo(figures.length)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.lock_rounded)),
        findsNothing,
      );

      // The round opens on the first card.
      await tester.tapFinder(tile, reason: 'the "Tarjetas de cifras" tile');
      await tester.waitFor(
        find.text(T.ratio(1, figures.length)),
        reason: 'the first card',
      );
      expect(app.location, '/cifras/tarjetas');
      expect(find.text(T.tarjetasTitulo.toUpperCase()), findsOneWidget);
      expect(find.text(T.verRespuesta), findsOneWidget);
      expect(find.text(T.laSabia), findsNothing);

      // The first card: its stem and the official answer behind the button.
      final firstStem = _stemOnScreen(app, figures);
      expect(firstStem, isNotNull, reason: 'the stem of the first card');
      expect(figures.map((q) => q.stem), contains(firstStem));
      await tester.tapText(T.verRespuesta, wait: _tapWait);
      await tester.waitFor(
        find.text(T.respuestaCorrecta),
        reason: 'the revealed answer',
      );
      expect(find.text(T.correcto), findsOneWidget);
      expect(find.text(T.explicacion), findsOneWidget);
      expect(find.text(T.laSabia), findsOneWidget);
      expect(find.text(T.repasarOtraVez), findsOneWidget);
      _expectOfficialAnswer(app, figures, firstStem!);

      // "La sabía": the next card.
      await tester.tapText(T.laSabia, wait: _tapWait);
      await tester.waitFor(
        find.text(T.ratio(2, figures.length)),
        reason: 'the second card',
      );
      expect(find.text(T.verRespuesta), findsOneWidget);

      // "Repasar otra vez": the card goes to the end of the deck and the
      // progress does not move.
      await tester.tapText(T.verRespuesta, wait: _tapWait);
      await tester.waitFor(find.text(T.laSabia), reason: 'the revealed card');
      await tester.tapText(T.repasarOtraVez, wait: _tapWait);
      await tester.waitUntil(
        () => find.text(T.verRespuesta).evaluate().isNotEmpty,
        reason: 'the next card',
      );
      expect(
        find.text(T.ratio(2, figures.length)),
        findsOneWidget,
        reason: 'a repeated card does not advance the progress',
      );

      // The rest of the deck, and the repeated card at the end of it.
      final summary = T.tarjetasResumen(figures.length - 1, figures.length);
      var answered = 0;
      while (find.text(T.verRespuesta).evaluate().isNotEmpty) {
        if (answered > figures.length + 2) {
          throw TestFailure('the deck of ${figures.length} cards never ended');
        }
        await _answerCard(app, known: true);
        answered++;
      }
      expect(
        answered,
        figures.length - 1,
        reason: 'every card but the two answered at first',
      );

      // The summary: how many were known at the first try, and the cards to
      // repeat.
      await tester.waitFor(find.text(summary), reason: 'the summary');
      expect(find.text(T.otraVez), findsOneWidget);
      expect(find.text(T.volver), findsOneWidget);
      expect(find.text(T.verRespuesta), findsNothing);

      // "Otra vez con las que repasé": only the repeated card, from scratch.
      await tester.tapText(T.otraVez, wait: _tapWait);
      await tester.waitFor(
        find.text(T.ratio(1, 1)),
        reason: 'the repeated card',
      );
      await tester.tapText(T.verRespuesta, wait: _tapWait);
      await tester.waitFor(find.text(T.laSabia), reason: 'the revealed card');
      await tester.tapText(T.laSabia, wait: _tapWait);
      await tester.waitFor(
        find.text(T.tarjetasResumen(1, 1)),
        reason: 'the summary of the repeated card',
      );
      expect(
        find.text(T.otraVez),
        findsNothing,
        reason: 'there is nothing left to repeat',
      );

      // "Volver" goes back to Inicio.
      await tester.tapText(T.volver, wait: _tapWait);
      await waitHome(app);

      // The round is only a review: it writes no attempt and no progress.
      expect(
        await app.container.read(attemptRepositoryProvider).all(),
        isEmpty,
      );
      tester.expectNoException('cifras_tarjetas_completa');
    },
    timeout: const Duration(minutes: 10),
  );
}
