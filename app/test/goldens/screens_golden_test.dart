@Tags(['golden'])
library;

import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/application/mock_service.dart'
    show StartedMock;
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../support/db_support.dart';
import '../support/screen_support.dart';
import '../support/settings_support.dart';
import '../support/study_support.dart';

/// Screenshot goldens of the "Sereno" screens (docs/design-sereno.md).
///
/// Each screen is captured three ways: 390x844 light, 390x844 dark and
/// 320x568 light with the text scaled x1.3 (the smallest phone with large
/// type). The data is deterministic: in-memory database, the real bundled
/// bank (plus one explanation where the screen needs it), a fixed clock
/// (Thu 15 Oct 2026, 18:30), seeded random sources and fixed attempts.
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

const _variants = [
  _Variant('light', Size(390, 844), 1),
  _Variant('dark', Size(390, 844), 1, dark: true),
  _Variant('small', Size(320, 568), 1.3),
];

/// Pumps the whole app at [variant] over an in-memory database. [bundle]
/// replaces the bundled question bank. The user owns the full version unless
Future<void> _pumpApp(
  WidgetTester tester,
  _Variant variant, {
  AssetBundle? bundle,

  List<Override> overrides = const [],
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
        ...overrides,
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// One golden test per [_variants] entry; [body] builds the scene and returns
/// once it is ready to be captured.
void _goldenScreen(
  String name,
  Future<void> Function(WidgetTester tester, _Variant variant) body, {
  AssetBundle Function()? bundle,
}) {
  for (final variant in _variants) {
    _goldenFile('${name}_${variant.name}', variant, body, bundle: bundle);
  }
}

/// A single golden, `<file>.png`, at one [variant] (extra states of a screen
/// at the smallest phone, where clipping shows first).
void _goldenFile(
  String file,
  _Variant variant,
  Future<void> Function(WidgetTester tester, _Variant variant) body, {
  AssetBundle Function()? bundle,

  List<Override> overrides = const [],
}) {
  testWidgets('$file (${variant.name})', (tester) async {
    try {
      await _pumpApp(
        tester,
        variant,
        bundle: bundle?.call(),
        overrides: overrides,
      );
      await body(tester, variant);
      await expectLater(
        find.byType(LeyAlBlancoApp),
        matchesGoldenFile('$file.png'),
      );
    } finally {
      await unmountApp(tester);
    }
  }, tags: ['golden']);
}

/// A stable history: four fifths of every tema answered right three times
/// over the last week, two questions per tema failed today. It gives Inicio a
/// mid-range probability, mastery rings and a short mistakes list.
Future<void> _seedHistory(WidgetTester tester) async {
  final bank = await bankOf(tester);
  final attempts = <Attempt>[];
  for (var tema = 1; tema <= 7; tema++) {
    final all = bank.where((q) => q.tema == tema).toList();
    for (final (i, q) in all.take((all.length * 4 / 5).ceil()).indexed) {
      for (final daysAgo in [6, 4, 2]) {
        attempts.add(
          attemptOn(
            q,
            correct: true,
            at: kTestNow.subtract(Duration(days: daysAgo)),
          ),
        );
      }
      if (i == 5 || i == 11) {
        attempts.add(attemptOn(q, correct: false, at: kTestNow));
      }
    }
  }
  await containerOf(tester).read(studyServiceProvider).recordAnswers(attempts);
  await tester.pumpAndSettle();
}

/// What a free user has: tema 1 well under way (four fifths answered right
/// three times, two questions failed today) and nothing of the locked temas.

/// A short, varied Fallos list: one failed question per tema, the first of
/// tema 2 failed twice.
Future<void> _seedMistakes(WidgetTester tester) async {
  final bank = await bankOf(tester);
  Question pick(int tema, int n) =>
      bank.where((q) => q.tema == tema).toList()[n];
  final attempts = [
    for (var tema = 1; tema <= 7; tema++)
      attemptOn(pick(tema, 2 * tema), correct: false, at: kTestNow),
    attemptOn(pick(2, 4), correct: false, at: kTestNow),
  ];
  await containerOf(tester).read(studyServiceProvider).recordAnswers(attempts);
  await tester.pumpAndSettle();
}

/// Starts a mock with a seeded draw and answers it through the controller:
/// the first [right] questions with the official answer, the next [wrong]
/// with a wrong option. With [submit] the mock is handed in.
Future<StartedMock> _playMock(
  WidgetTester tester, {
  required int right,
  required int wrong,
  required bool submit,
}) async {
  final container = containerOf(tester);
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < right + wrong; i++) {
    controller.goTo(i);
    final q = started.questions[i];
    controller.select(i < right ? q.answer : wrongOption(q));
  }
  controller.goTo(0);
  if (submit) await controller.submit();
  await controller.pendingSaves;
  return started;
}

/// Scrolls the result so "Solo falladas" sits near the top of the screen.
Future<void> _scrollToFilter(WidgetTester tester) async {
  final chip = find.widgetWithText(FilterChip, 'Solo falladas');
  await Scrollable.ensureVisible(tester.element(chip), alignment: 0.12);
  await tester.pumpAndSettle();
}

/// The bank with an explanation and an article on its first question of
/// tema 1, so the Pregunta golden shows the whole explanation.
AssetBundle _bankWithExplanation() {
  final json = realQuestionsJson();
  final first = json.firstWhere((q) => q['tema'] == 1);
  first['explanation'] = {
    'es':
        'Texto de ejemplo de la explicación: resume en pocas líneas por qué '
        'la respuesta marcada como correcta es la que figura en el '
        'cuestionario oficial.',
  };
  first['article'] = 'Art. 3 RD 137/1993';
  return FakeAssetBundle.edition(json);
}

/// Like [_bankWithExplanation], plus a legal-reform notice (and its flag) on
/// that question, so the Pregunta golden shows the amber callout.
AssetBundle _bankWithNotice() {
  final json = realQuestionsJson();
  final first = json.firstWhere((q) => q['tema'] == 1);
  first['explanation'] = {
    'es':
        'Texto de ejemplo de la explicación: resume en pocas líneas por qué '
        'la respuesta marcada como correcta es la que figura en el '
        'cuestionario oficial.',
  };
  first['article'] = 'Art. 3 RD 137/1993';
  first['notice'] = {
    'es':
        'Ojo: el cuestionario dice una cosa; tras la reforma de 2023 el '
        'artículo 5 dice otra distinta. Para el examen, responde lo que '
        'figura en el cuestionario.',
  };
  first['flags'] = ['discrepancia_reforma_2023'];
  return FakeAssetBundle.edition(json);
}

/// Answers the first question of tema 1 wrong and scrolls to the end of its
/// explanation (notice, explanation and article chip).
Future<void> _answerWithNotice(WidgetTester tester, _Variant variant) async {
  await pushRoute(tester, '/tema/1');
  final q = containerOf(tester)
      .read(practiceControllerProvider(const TemaPractice(1)))
      .requireValue
      .session!
      .currentQuestion;
  await tapOption(tester, wrongOption(q));
  await tester.ensureVisible(find.byType(ArticleChip));
  await tester.pumpAndSettle();
}

void main() {
  _goldenScreen('inicio', (tester, variant) async {
    await _seedHistory(tester);
  });

  // user's.)

  // the same one).

  _goldenScreen('pregunta', (tester, variant) async {
    await pushRoute(tester, '/tema/1');
    final q = containerOf(tester)
        .read(practiceControllerProvider(const TemaPractice(1)))
        .requireValue
        .session!
        .currentQuestion;
    await tapOption(tester, wrongOption(q));
    // Bring the end of the explanation (the article chip) into view.
    await tester.ensureVisible(find.byType(ArticleChip));
    await tester.pumpAndSettle();
  }, bundle: _bankWithExplanation);

  // The notice callout above the explanation (tag golden, light and dark).
  _goldenFile(
    'pregunta_aviso_light',
    _variants[0],
    _answerWithNotice,
    bundle: _bankWithNotice,
  );
  _goldenFile(
    'pregunta_aviso_dark',
    _variants[1],
    _answerWithNotice,
    bundle: _bankWithNotice,
  );

  // The quiet «¿Ves un error? Avísanos» action under the article chip (only
  // shown when the build has a support address: overridden here).
  _goldenFile(
    'pregunta_avisanos_light',
    _variants[0],
    (tester, variant) async {
      await _answerWithNotice(tester, variant);
      await tester.ensureVisible(find.text('¿Ves un error? Avísanos'));
      await tester.pumpAndSettle();
    },
    bundle: _bankWithNotice,
    overrides: [settingsLinksProvider.overrideWithValue(kTestLinks)],
  );

  _goldenScreen('simulacro', (tester, variant) async {
    // Four answered, the fifth on screen with its pick selected.
    final mock = await _playMock(tester, right: 4, wrong: 0, submit: false);
    final controller = containerOf(tester)
        .read(mockControllerProvider(mock.id).notifier);
    controller
      ..goTo(4)
      ..select(1);
    await controller.pendingSaves;
    await pushRoute(tester, '/simulacro/${mock.id}');
  });

  // Smallest phone, large text, nothing answered or scrolled yet: overline,
  // stem and the three options as they first appear.
  _goldenFile('pregunta_small_top', _variants[2], (tester, variant) async {
    await pushRoute(tester, '/tema/1');
  });

  // Smallest phone, large text, scrolled down to the bottom bar (the buttons
  // stack there): checks nothing is clipped under them.
  _goldenFile('simulacro_small_bottom', _variants[2], (tester, variant) async {
    final mock = await _playMock(tester, right: 4, wrong: 0, submit: false);
    await pushRoute(tester, '/simulacro/${mock.id}');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Entregar'));
    await tester.pumpAndSettle();
  });

  _goldenScreen('resultado_apto', (tester, variant) async {
    final mock = await _playMock(tester, right: 17, wrong: 3, submit: true);
    await pushRoute(tester, '/simulacro/${mock.id}/resultado');
  });

  _goldenScreen('resultado_no_apto', (tester, variant) async {
    final mock = await _playMock(tester, right: 12, wrong: 8, submit: true);
    await pushRoute(tester, '/simulacro/${mock.id}/resultado');
  });

  // Simulacro intro with a mock left open ("Continuar simulacro") and one
  // finished ("Tus simulacros").
  _goldenScreen('simulacro_intro', (tester, variant) async {
    await _playMock(tester, right: 17, wrong: 3, submit: true);
    await _playMock(tester, right: 4, wrong: 2, submit: false);
    await pushRoute(tester, '/simulacro');
  });

  // The question list of the result: "Solo falladas" on (the default) and off.
  _goldenFile('simulacro_resultado_preguntas_light', _variants[0], (
    tester,
    variant,
  ) async {
    final mock = await _playMock(tester, right: 12, wrong: 8, submit: true);
    await pushRoute(tester, '/simulacro/${mock.id}/resultado');
    await _scrollToFilter(tester);
  });
  _goldenFile('simulacro_resultado_todas_light', _variants[0], (
    tester,
    variant,
  ) async {
    final mock = await _playMock(tester, right: 12, wrong: 8, submit: true);
    await pushRoute(tester, '/simulacro/${mock.id}/resultado');
    await _scrollToFilter(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Solo falladas'));
    await tester.pumpAndSettle();
    await _scrollToFilter(tester);
  });

  // Review of a failed question with "Anterior" / "Siguiente".
  _goldenScreen('simulacro_revision', (tester, variant) async {
    final mock = await _playMock(tester, right: 12, wrong: 8, submit: true);
    await pushRoute(tester, '/simulacro/${mock.id}/revision/12?falladas=1');
  });

  _goldenScreen('fallos', (tester, variant) async {
    await _seedMistakes(tester);
    await pushRoute(tester, '/fallos');
  });
}
