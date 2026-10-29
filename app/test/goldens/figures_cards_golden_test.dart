@Tags(['golden'])
library;

import 'dart:math';

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../support/db_support.dart';
import '../support/screen_support.dart';

/// Goldens of the "Tarjetas de cifras" screen (/cifras/tarjetas): the front of
/// a card, its back (the official answer, our explanation, the cited article
/// and the reform notice) and the summary of the round. Same conditions as
/// `daily_figures_golden_test.dart` (390x844 light and dark, 320x568 light at
/// x1.3 text; in-memory database, the real bank with only the flags changed,
/// a fixed clock and a seeded shuffle). Regenerate with
/// `flutter test --update-goldens test/goldens/figures_cards_golden_test.dart`.
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

/// The real bank with only the flags changed: the deck holds exactly [ids].
/// The stems, options, official answers, explanations, articles and notices
/// are the real ones.
AssetBundle _bankFlaggedOnly(Set<String> ids) {
  final json = realQuestionsJson();
  for (final q in json) {
    final flags = (q['flags'] as List? ?? const []).cast<String>().toList()
      ..remove(kFiguresFlag);
    if (ids.contains(q['id'])) flags.add(kFiguresFlag);
    q['flags'] = flags;
  }
  return FakeAssetBundle.edition(json);
}

/// The first question of the bank flagged `cifras` with our own explanation,
/// the cited article and the reform notice: the back of its card shows all
/// three.
Question _noticeQuestion() => realQuestionsJson()
    .map(Question.fromJson)
    .firstWhere(
      (q) =>
          q.isFigures &&
          q.notice != null &&
          q.explanation != null &&
          q.article != null,
    );

/// Another flagged question, so the summary of a round has a deck of two.
Question _otherFiguresQuestion(Question otherThan) => realQuestionsJson()
    .map(Question.fromJson)
    .firstWhere((q) => q.isFigures && q.id != otherThan.id);

const _reveal = 'Ver respuesta';
const _known = 'La sabía';
const _again = 'Repasar otra vez';

/// Taps a button of the card, scrolling it into view first (on the smallest
/// phone the buttons are below the fold).
Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// A footer snapshot must contain the whole button, not just its label or
/// an off-screen widget that happens to exist in the tree.
void _expectVisibleButton(WidgetTester tester, Finder button) {
  expect(button.hitTestable(), findsOneWidget);
  final viewport = tester.getRect(find.byType(SingleChildScrollView));
  final rect = tester.getRect(button);
  expect(rect.intersect(viewport), rect);
}

void _expectAnswer(Question question) {
  final letter = String.fromCharCode(0x41 + question.answer);
  expect(
    find.text('$letter. ${question.options[question.answer]}'),
    findsOneWidget,
  );
  expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  expect(find.text('La respuesta'), findsOneWidget);
  expect(find.text('Correcto'), findsNothing);
  expect(find.text(question.notice!), findsOneWidget);
  expect(find.text(question.explanation!), findsOneWidget);
  expect(find.byType(ArticleChip), findsOneWidget);
}

void main() {
  final notice = _noticeQuestion();
  final other = _otherFiguresQuestion(notice);
  final one = _bankFlaggedOnly({notice.id});
  final two = _bankFlaggedOnly({notice.id, other.id});

  for (final variant in [_light, _dark, _small]) {
    // The front of a card: the stem and the button that turns it over.
    _golden('cifras_tarjetas_anverso_${variant.name}', variant, (tester) async {
      await pushRoute(tester, '/cifras/tarjetas');
      expect(find.text(notice.stem), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      _expectVisibleButton(tester, find.widgetWithText(FilledButton, _reveal));
    }, bundle: one);

    // The back of the card: the official answer before assessing recall.
    _golden('cifras_tarjetas_reverso_${variant.name}', variant, (tester) async {
      await pushRoute(tester, '/cifras/tarjetas');
      await _tap(tester, _reveal);
      _expectAnswer(notice);
    }, bundle: one);

    // The end of the back: the explanation, the article and the buttons.
    _golden('cifras_tarjetas_reverso_fin_${variant.name}', variant, (
      tester,
    ) async {
      await pushRoute(tester, '/cifras/tarjetas');
      await _tap(tester, _reveal);
      _expectAnswer(notice);
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, _again));
      await tester.pumpAndSettle();
      _expectVisibleButton(tester, find.widgetWithText(FilledButton, _known));
      _expectVisibleButton(tester, find.widgetWithText(OutlinedButton, _again));
    }, bundle: one);

    // The summary of the round: the score, the restart of the cards to
    // review and the way back.
    _golden('cifras_tarjetas_resumen_${variant.name}', variant, (tester) async {
      await pushRoute(tester, '/cifras/tarjetas');
      await _tap(tester, _reveal);
      // The first card goes back to the deck to be reviewed later.
      await _tap(tester, _again);
      await _tap(tester, _reveal);
      await _tap(tester, _known);
      await _tap(tester, _reveal);
      await _tap(tester, _known);
      expect(find.text('Sabías 1 de 2 a la primera'), findsOneWidget);
      _expectVisibleButton(
        tester,
        find.widgetWithText(FilledButton, 'Otra vez con las que repasé'),
      );
      _expectVisibleButton(
        tester,
        find.widgetWithText(OutlinedButton, 'Volver'),
      );
    }, bundle: two);
  }
}
