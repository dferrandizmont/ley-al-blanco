@Tags(['golden'])
library;

import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../support/db_support.dart';
import '../support/screen_support.dart';

/// Goldens of the doubtful marks of the mock and of the question search
/// (docs/design-sereno.md): 390x844 light, 390x844 dark and 320x568 light
/// with the text scaled x1.3. Regenerate with
/// `flutter test --update-goldens test/goldens/search_flag_golden_test.dart`.
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

Future<void> _pumpApp(WidgetTester tester, _Variant variant) async {
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
        randomProvider.overrideWithValue(Random(7)),
        ...databaseTestOverrides(),
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _golden(
  String file,
  List<_Variant> variants,
  Future<void> Function(WidgetTester tester) body,
) {
  for (final variant in variants) {
    testWidgets('${file}_${variant.name}', (tester) async {
      try {
        await _pumpApp(tester, variant);
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

/// A started mock with the questions 3, 7 and 12 (0-based) marked as doubtful
/// and the first ten answered, opened on question 8 (marked).
Future<int> _markedMock(WidgetTester tester) async {
  final container = containerOf(tester);
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < 10; i++) {
    controller
      ..goTo(i)
      ..select(i % 3);
  }
  for (final i in [3, 7, 12]) {
    controller
      ..goTo(i)
      ..toggleFlag();
  }
  controller.goTo(7);
  await controller.pendingSaves;
  return started.id;
}

void main() {
  // The question on screen with its mark on.
  _golden('simulacro_dudosa', [_light, _dark, _small], (tester) async {
    final id = await _markedMock(tester);
    await pushRoute(tester, '/simulacro/$id');
  });

  // The map: answered, unanswered and doubtful cells, summary and legend.
  _golden('simulacro_navegador', [_light, _dark, _small], (tester) async {
    final id = await _markedMock(tester);
    await pushRoute(tester, '/simulacro/$id');
    // On the smallest phone the bar scrolls with the question.
    await tester.ensureVisible(find.text('Preguntas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preguntas'));
    await tester.pumpAndSettle();
  });

  // The search with results (the full version).
  _golden('buscar', [_light, _dark, _small], (tester) async {
    await pushRoute(tester, '/buscar');
    await tester.enterText(find.byType(TextField), 'licencia armas');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });

  // Before typing anything.
  _golden('buscar_inicio', [_light], (tester) async {
    await pushRoute(tester, '/buscar');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  });
}
