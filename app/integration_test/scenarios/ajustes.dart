import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/qa_harness.dart';
import '../support/qa_texts.dart';

// Ajustes: appearance, bank information, license page and the fixed notice.
Future<void> _openAjustes(QaApp app) async {
  await app.tester.tapFinder(
    find.byTooltip(T.ajustes),
    reason: 'Ajustes button',
  );
  await app.tester.waitFor(find.text(T.ajustes), reason: 'the Ajustes title');
  await app.tester.pumpFor(const Duration(milliseconds: 300));
}

/// Scrolls the Ajustes list until [finder] is built and visible.
Future<void> _see(WidgetTester tester, Finder finder, {String? what}) async {
  if (finder.evaluate().isEmpty) {
    try {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
    } on Object {
      throw TestFailure(
        'Ajustes does not show ${what ?? finder}. '
        'On screen: ${tester.visibleTexts().take(40).join(' | ')}',
      );
    }
  }
  expect(finder, findsWidgets, reason: what);
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(Scaffold).first)).brightness;

/// The theme option labelled [label]: a segmented button, a radio row...
Finder _themeOption(String label) => find.text(label);

void registerAjustes() {
  qaScenario('ajustes', 'banco, aviso legal y licencias', (tester) async {
    final app = await launchApp(tester);
    await _openAjustes(app);

    expect(find.text('Restaurar compras'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    // Bank information: edition, number of questions, retrieved date.
    await _see(tester, find.text(T.edicion), what: 'edition');
    await _see(tester, find.text('423'), what: 'question count');
    await _see(
      tester,
      find.textContaining(RegExp('consultad', caseSensitive: false)),
      what: 'retrieved date ("consultado")',
    );

    // Legal notice of an independent, non-official app.
    await _see(tester, find.textContaining(T.legal), what: 'legal text');
    tester.expectNoException('ajustes');

    await _see(tester, find.text('Licencias de código abierto'));
  });

  qaScenario('ajustes_tema', 'tema Sistema / Claro / Oscuro cambia la app', (
    tester,
  ) async {
    final app = await launchApp(tester);
    await _openAjustes(app);
    expect(_brightness(tester), Brightness.light, reason: 'system = light');

    await _see(tester, _themeOption(T.temaOscuro), what: 'Oscuro option');
    await tester.tapFinder(_themeOption(T.temaOscuro));
    await tester.waitUntil(
      () => _brightness(tester) == Brightness.dark,
      reason: 'dark theme after choosing Oscuro',
    );

    await tester.tapFinder(_themeOption(T.temaClaro));
    await tester.waitUntil(
      () => _brightness(tester) == Brightness.light,
      reason: 'light theme after choosing Claro',
    );

    // Sistema follows the phone: dark phone -> dark app.
    await tester.tapFinder(_themeOption(T.temaSistema));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.waitUntil(
      () => _brightness(tester) == Brightness.dark,
      reason: 'system theme follows a dark phone',
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.waitUntil(
      () => _brightness(tester) == Brightness.light,
      reason: 'system theme follows a light phone',
    );

    // The choice survives a restart.
    await tester.tapFinder(_themeOption(T.temaOscuro));
    await tester.waitUntil(() => _brightness(tester) == Brightness.dark);
    await app.restart();
    expect(_brightness(tester), Brightness.dark, reason: 'persisted theme');
    tester.expectNoException('ajustes_tema');
  });
}
