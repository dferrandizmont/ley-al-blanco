import 'package:apto_armas/features/content/domain/question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/play_mock_support.dart';
import 'support/screen_support.dart';

/// Flutter's own accessibility checks over the main screens, in both themes:
/// every tappable thing is at least 48 x 48 dp (the Android guideline, also
/// what the Play pre-launch report checks), every text has enough contrast
/// against what is drawn behind it and every tappable thing has a spoken
/// label (checked on the cards of "Tarjetas de cifras").
///
/// The screens are the ones the manual tests of 0.6.0 flagged (internal test reports, 
/// 0.6.0/revision-opus.md, R-02, R-08, R-09), plus the figures cards.

/// A screen to check: how to reach it from Inicio.
class _Screen {
  const _Screen(this.name, this.open, {this.bundle});

  final String name;
  final Future<void> Function(WidgetTester tester) open;

  /// Replaces the bundled question bank (the cards need a fixed deck).
  final AssetBundle? bundle;
}

/// The bank with a single flagged question: the first one with our own
/// explanation, the cited article and the reform notice, so the back of its
/// card shows all three. Only the flags change; the stems, the official
/// answers and our layer are the real ones.
AssetBundle _cardsBank() {
  final json = realQuestionsJson();
  final id = json
      .map(Question.fromJson)
      .firstWhere(
        (q) =>
            q.isFigures &&
            q.notice != null &&
            q.explanation != null &&
            q.article != null,
      )
      .id;
  for (final q in json) {
    final flags = (q['flags'] as List? ?? const []).cast<String>().toList()
      ..remove(kFiguresFlag);
    if (q['id'] == id) flags.add(kFiguresFlag);
    q['flags'] = flags;
  }
  return FakeAssetBundle.edition(json);
}

/// The same bank for the two faces of the cards (read once).
final AssetBundle _cardsBundle = _cardsBank();

/// Turns the card over: the back with the official answer, our explanation,
/// the article and the reform notice.
Future<void> _turnCard(WidgetTester tester) async {
  final button = find.text('Ver respuesta');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// The "Tarjetas de cifras" screen, in its two faces: the front of a card and
/// its back.
final _cardsScreens = [
  _Screen(
    'Tarjetas de cifras',
    (tester) => pushRoute(tester, '/cifras/tarjetas'),
    bundle: _cardsBundle,
  ),
  _Screen('Tarjetas de cifras (reverso)', (tester) async {
    await pushRoute(tester, '/cifras/tarjetas');
    await _turnCard(tester);
  }, bundle: _cardsBundle),
];

final _screens = [
  _Screen('Inicio', (tester) async {}),
  _Screen('Pregunta', (tester) => pushRoute(tester, '/tema/1')),
  _Screen('Simulacro', (tester) async {
    final mock = await playMock(tester, right: 4, wrong: 0, submit: false);
    await pushRoute(tester, '/simulacro/${mock.id}');
  }),
  _Screen('Resultado', (tester) async {
    final mock = await playMock(tester, right: 12, wrong: 8, submit: true);
    await pushRoute(tester, '/simulacro/${mock.id}/resultado');
  }),
  _Screen('Ajustes', (tester) => pushRoute(tester, '/ajustes')),
  _Screen('Fallos', (tester) => pushRoute(tester, '/fallos')),
  _Screen('Teoría', (tester) => pushRoute(tester, '/teoria')),
  _Screen('Teoría, tema 5', (tester) async {
    await pushRoute(tester, '/teoria/t5');
  }),
  ..._cardsScreens,
];

/// Opens [screen] at 390 x 844 in light or dark and returns the semantics
/// handle (dispose it at the end of the test).
Future<SemanticsHandle> _open(
  WidgetTester tester,
  _Screen screen, {
  required bool dark,
}) async {
  final handle = tester.ensureSemantics();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await pumpFullApp(tester, bundle: screen.bundle);
  await screen.open(tester);
  return handle;
}

void main() {
  for (final dark in [false, true]) {
    for (final screen in _screens) {
      final mode = dark ? 'dark' : 'light';

      testScreen('${screen.name} ($mode): tap targets are at least 48 dp', (
        tester,
      ) async {
        final handle = await _open(tester, screen, dark: dark);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });

      testScreen('${screen.name} ($mode): text contrast', (tester) async {
        final handle = await _open(tester, screen, dark: dark);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  // The cards also need a spoken label on every tappable thing: the close
  // button, "Ver respuesta" and the two answers of the back.
  for (final dark in [false, true]) {
    for (final screen in _cardsScreens) {
      final mode = dark ? 'dark' : 'light';
      testScreen('${screen.name} ($mode): tappable things have a label', (
        tester,
      ) async {
        final handle = await _open(tester, screen, dark: dark);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  }
}
