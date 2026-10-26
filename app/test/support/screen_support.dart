import 'package:apto_armas/core/router.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:flutter/material.dart';
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
