@Tags(['golden'])
library;

import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/daily/application/daily_providers.dart';
import 'package:apto_armas/features/daily/domain/daily_question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../support/db_support.dart';
import '../support/screen_support.dart';

/// Goldens of the "Pregunta del día" card and the "Cifras y plazos" tile of
/// Inicio (scrolled to them), plus the empty state of the mode for a free
/// user. Same conditions as `screens_golden_test.dart` (390x844 light and
/// dark, 320x568 light at x1.3 text; in-memory database, the real bank, a
/// fixed clock). Regenerate with `flutter test --update-goldens --tags golden`.
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

  AssetBundle? bundle,
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
        randomProvider.overrideWithValue(Random(7)),
        ...databaseTestOverrides(bundle: bundle),
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void _golden(
  String file,
  _Variant variant,
  Future<void> Function(WidgetTester tester) body, {

  AssetBundle? bundle,
}) {
  testWidgets('$file (${variant.name})', (tester) async {
    try {
      await _pump(tester, variant, bundle: bundle);
      await body(tester);
      await expectLater(
        find.byType(LeyAlBlancoApp),
        matchesGoldenFile('$file.png'),
      );
    } finally {
      await unmountApp(tester);
    }
  }, tags: ['golden']);
}

/// Scrolls Inicio until [text] is on screen, then a bit more so it is not
/// glued to the bottom edge.
Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Streak of [days] ending [daysAgo] days before the fixed "today".
Future<void> _seedStreak(
  WidgetTester tester, {
  required int days,
  required int daysAgo,
}) async {
  final container = containerOf(tester);
  final status = await container.read(dailyStatusProvider.future);
  await container
      .read(dailyRepositoryProvider)
      .save(
        DailyProgress(
          lastDay: isoDay(kTestNow.subtract(Duration(days: daysAgo))),
          streak: days,
          lastQuestionId: status.question!.id,
        ),
      );
  container.invalidate(dailyProgressProvider);
  container.invalidate(dailyStatusProvider);
  await tester.pumpAndSettle();
}

void main() {
  for (final variant in [_light, _dark, _small]) {
    // A new day: the question, with the streak of three days kept from
    // yesterday.
    _golden('inicio_diaria_${variant.name}', variant, (tester) async {
      await _seedStreak(tester, days: 3, daysAgo: 1);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -140),
      );
      await tester.pumpAndSettle();
    });
  }

  // Answered today: the calm state with the streak.
  _golden('inicio_diaria_hecha_light', _light, (tester) async {
    await _seedStreak(tester, days: 4, daysAgo: 0);
  });

  _golden('inicio_cifras_light', _light, (tester) async {
    await _scrollTo(tester, 'Cifras y plazos');
  });
  _golden('inicio_cifras_dark', _dark, (tester) async {
    await _scrollTo(tester, 'Cifras y plazos');
  });
  _golden('inicio_cifras_small', _small, (tester) async {
    await _scrollTo(tester, 'Cifras y plazos');
  });

  // Empty figures bank: the empty state offers a return to Inicio.
  final noFigures = realQuestionsJson();
  for (final question in noFigures) {
    (question['flags'] as List).remove('cifras');
  }
  _golden('cifras_vacio_light', _light, (tester) async {
    await openRoute(tester, '/cifras');
  }, bundle: FakeAssetBundle.edition(noFigures));
}
