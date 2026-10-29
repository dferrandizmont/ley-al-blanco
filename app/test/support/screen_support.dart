import 'package:apto_armas/core/router.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The provider container of the app under test.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

GoRouter routerOf(WidgetTester tester) =>
    containerOf(tester).read(routerProvider);

String locationOf(WidgetTester tester) => routerOf(tester).state.uri.toString();

/// Navigates with `go` and waits for the screen to settle.
Future<void> openRoute(WidgetTester tester, String location) async {
  routerOf(tester).go(location);
  await tester.pumpAndSettle();
}

/// Like a tap on a link: `push`, so the page below stays mounted.
Future<void> pushRoute(WidgetTester tester, String location) async {
  routerOf(tester).push(location);
  await tester.pumpAndSettle();
}

/// The active bank, in bank order.
Future<List<Question>> bankOf(WidgetTester tester) =>
    containerOf(tester).read(questionsProvider.future);

/// Taps the `index`-th option card (scrolling it into view first).
Future<void> tapOption(WidgetTester tester, int index) async {
  final card = find.byType(OptionCard).at(index);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

/// The [OptionState] of every option card on screen, in order.
List<OptionState> optionStates(WidgetTester tester) => [
  for (final card in tester.widgetList<OptionCard>(find.byType(OptionCard)))
    card.state,
];

/// Taps the floating "Siguiente" (or "Terminar") pill.
Future<void> tapNext(WidgetTester tester, {String label = 'Siguiente'}) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

/// Unmounts the app and lets Drift's zero-duration "stream closed" timers run,
/// so the test does not end with a pending timer.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

/// No word of [text] is split in the middle: every one of them is painted on
/// a single line.
void expectWordsNotSplit(WidgetTester tester, Finder finder, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    expect(boxes, hasLength(1), reason: '"${word.group(0)}" is split');
  }
}

/// Every word of [text] is inside the width of its paragraph: nothing is cut
/// and nothing hangs out of the space it has.
void expectWordsInside(WidgetTester tester, Finder finder, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    for (final box in boxes) {
      expect(
        box.left,
        greaterThanOrEqualTo(-0.5),
        reason: '"${word.group(0)}" hangs out on the left',
      );
      expect(
        box.right,
        lessThanOrEqualTo(paragraph.size.width + 0.5),
        reason: '"${word.group(0)}" hangs out of the paragraph',
      );
    }
  }
}

/// The size the text of [finder] is really drawn at: the size of its style
/// with the scale of the user (the one the text sees, already capped when it
/// did not fit).
double effectiveFontSize(WidgetTester tester, Finder finder) {
  final style = tester.widget<Text>(finder).style!;
  final scaler = MediaQuery.textScalerOf(tester.element(finder));
  return scaler.scale(style.fontSize!);
}

/// `testWidgets` for screens backed by Drift streams: always unmounts the app
/// at the end (also when the body fails).
void testScreen(
  String description,
  Future<void> Function(WidgetTester tester) body, {
  Timeout? timeout,
}) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await unmountApp(tester);
    }
  }, timeout: timeout);
}
