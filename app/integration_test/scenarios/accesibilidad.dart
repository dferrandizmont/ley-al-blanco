import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';
import '../support/qa_ui.dart';

/// Visits the main screens and fails on any framework exception (a RenderFlex
/// overflow, a build error) at every step. Used with dark mode, large text and
/// a small screen.
Future<void> _tour(
  QaApp app,
  String label, {
  Brightness? expectBrightness,
  double textScale = 1,
  Size? logicalSize,
}) async {
  final tester = app.tester;
  void ok(String where) => tester.expectNoException('$label / $where');

  // The conditions under test really reached the app.
  final media = MediaQuery.of(tester.element(find.byType(Scaffold).first));
  expect(media.textScaler.scale(100), closeTo(100 * textScale, 0.5));
  if (logicalSize != null) {
    expect(media.size.width, closeTo(logicalSize.width, 0.5));
    expect(media.size.height, closeTo(logicalSize.height, 0.5));
  }

  // Inicio.
  ok('Inicio');
  if (expectBrightness != null) {
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.brightness, expectBrightness, reason: '$label: theme');
  }
  expect(find.text(T.continuarCount(15)), findsOneWidget);
  // Scroll the whole page so every row is laid out and measured.
  await tester.drag(
    find.byType(SingleChildScrollView).first,
    const Offset(0, -4000),
  );
  await tester.pumpFor(const Duration(milliseconds: 400));
  ok('Inicio (bottom)');
  await tester.drag(
    find.byType(SingleChildScrollView).first,
    const Offset(0, 4000),
  );
  await tester.pumpFor(const Duration(milliseconds: 400));

  // Practice: a wrong answer shows the verdict and the explanation.
  await openTema(app, 1);
  ok('practica (question)');
  await answerPractice(app, correct: false);
  await tester.pumpFor(const Duration(milliseconds: 300));
  ok('practica (feedback)');
  await closePracticeToHome(app);
  ok('Inicio after practice');

  // Fallos.
  await tester.tapText(T.fallos);
  await tester.waitFor(find.text(T.falladaUnaVez));
  ok('Fallos');
  await tester.tapFinder(find.byTooltip('Atrás'));
  await waitHome(app);

  // Simulacro: question, navigator, leave dialog.
  await startMockFromHome(app);
  ok('simulacro (question)');
  final q = await answerMock(app, 1, outcome: true);
  expect(q.question.tema, 1);
  ok('simulacro (answered)');
  await tester.tapText(T.preguntas);
  await tester.waitFor(find.byType(MockNavigator));
  await tester.pumpFor(const Duration(milliseconds: 300));
  ok('simulacro (navigator)');
  await tester.tapFinder(
    find.descendant(of: find.byType(MockNavigator), matching: find.text('1')),
  );
  await tester.waitGone(find.byType(MockNavigator));
  await askToLeaveMock(app);
  ok('simulacro (leave dialog)');
  await confirmLeaveMock(app);

  // Ajustes.
  await tester.tapFinder(find.byTooltip(T.ajustes));
  await tester.waitFor(find.text(T.ajustes));
  await tester.pumpFor(const Duration(milliseconds: 300));
  ok('Ajustes');
  await tester.tapFinder(find.byTooltip('Atrás'));
  await waitHome(app);
  ok('end');
}

void registerAccesibilidad() {
  qaScenario(
    'modo_oscuro',
    'arranque, practica, simulacro y Ajustes en modo oscuro sin excepciones',
    (tester) async {
      final app = await launchApp(tester, dark: true);
      await _tour(app, 'oscuro', expectBrightness: Brightness.dark);
    },
  );

  qaScenario(
    'texto_grande',
    'las mismas pantallas con texto al 130 % sin desbordes',
    (tester) async {
      final app = await launchApp(tester, textScale: 1.3);
      await _tour(
        app,
        'texto 1.3',
        expectBrightness: Brightness.light,
        textScale: 1.3,
      );
    },
  );

  qaScenario(
    'pantalla_pequena',
    'iPhone SE (320x568), texto al 130 % y modo oscuro: sin desbordes',
    (tester) async {
      const size = Size(320, 568);
      final app = await launchApp(
        tester,
        textScale: 1.3,
        dark: true,
        logicalSize: size,
      );
      await _tour(
        app,
        'SE 320x568',
        expectBrightness: Brightness.dark,
        textScale: 1.3,
        logicalSize: size,
      );
    },
  );
}
