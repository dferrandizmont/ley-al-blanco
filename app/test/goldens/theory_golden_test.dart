@Tags(['golden'])
library;

import 'dart:async';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/theory/presentation/theory_diagrams.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../support/db_support.dart';
import '../support/screen_support.dart';
import '../support/theory_support.dart';

/// Screenshot goldens of Teoría (docs/design-sereno.md): the list, the reader
/// and the three diagrams, at 390x844 light, 390x844 dark and 320x568 light
/// with the text scaled x1.3. The content is the fixture of
/// `support/theory_support.dart`, not the real summaries.
///
/// Regenerate with `flutter test --update-goldens --tags golden`. Goldens are
/// canonical on Windows; elsewhere the comparison is skipped (see
/// `flutter_test_config.dart`).
class _Variant {
  const _Variant(this.name, this.size, this.scale, {this.dark = false});

  final String name;
  final Size size;
  final double scale;
  final bool dark;
}

const _light = _Variant('light', Size(390, 844), 1);
const _dark = _Variant('dark', Size(390, 844), 1, dark: true);
const _small = _Variant('small', Size(320, 568), 1.3);

Future<void> _pump(
  WidgetTester tester,
  _Variant variant, {
  required bool extras,
}) async {
  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
  tester.platformDispatcher.platformBrightnessTestValue = variant.dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => kTestNow),
        ...databaseTestOverrides(
          bundle: theoryBundle(theory: theoryFixtureJson(extras: extras)),
        ),
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _golden(
  String file,
  List<_Variant> variants,
  Future<void> Function(WidgetTester tester) body, {

  /// The fixture with «Autorización para menores (AEM)» and the glossary.
  bool extras = false,
}) {
  for (final variant in variants) {
    testWidgets('${file}_${variant.name}', (tester) async {
      try {
        await _pump(tester, variant, extras: extras);
        await body(tester);
        await expectLater(
          find.byType(LeyAlBlancoApp),
          matchesGoldenFile('${file}_${variant.name}.png'),
        );
      } finally {
        await unmountApp(tester);
      }
    }, tags: ['golden']);
  }
}

/// Scrolls the list down until [text] is on screen.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
}

/// Unfolds the diagrams section of tema 1 and puts diagram [index] near the
/// top of the screen.
Future<void> _showDiagram(WidgetTester tester, int index) async {
  await openRoute(tester, '/teoria/t1');
  await tester.ensureVisible(find.text('Esquemas de seguridad'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Esquemas de seguridad'));
  await tester.pumpAndSettle();
  final diagram = find.byType(TheoryDiagram).at(index);
  // Not awaited: the animation only advances when the test pumps.
  unawaited(
    Scrollable.ensureVisible(
      tester.element(diagram),
      alignment: 0.1,
      duration: const Duration(milliseconds: 1),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  _golden('teoria_lista', [_light, _dark, _small], (tester) async {
    await openRoute(tester, '/teoria');
  });

  // The «Para completar» card (AEM and glossary), at the end of the list.
  _golden('teoria_lista_extras', [_light, _dark, _small], (tester) async {
    await openRoute(tester, '/teoria');
    await _scrollTo(tester, 'Glosario');
  }, extras: true);

  _golden('teoria_glosario', [_light, _dark, _small], (tester) async {
    await openRoute(tester, '/teoria/glosario');
  }, extras: true);

  // A search: three terms left, the sections without a match gone.
  _golden('teoria_glosario_busqueda', [_light, _small], (tester) async {
    await openRoute(tester, '/teoria/glosario');
    await tester.enterText(find.byType(TextField), 'fulminante');
    await tester.pumpAndSettle();
  }, extras: true);

  _golden('teoria_lector', [_light, _dark, _small], (tester) async {
    await openRoute(tester, '/teoria/t1');
  });

  _golden('teoria_diagrama_galeria', [_light, _dark, _small], (tester) async {
    await _showDiagram(tester, 0);
  });

  _golden('teoria_diagrama_zona', [_light, _dark, _small], (tester) async {
    await _showDiagram(tester, 1);
  });

  _golden('teoria_diagrama_secuencia', [_light, _small], (tester) async {
    await _showDiagram(tester, 2);
  });
}
