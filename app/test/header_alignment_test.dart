import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/apto_app_bar.dart';
import 'package:apto_armas/core/widgets/raised_card.dart';
import 'package:apto_armas/core/widgets/round_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';

/// The 44 dp circle that the first [RoundIconButton] draws.
Rect _circle(WidgetTester tester, {int index = 0}) {
  final button = find.byType(RoundIconButton).at(index);
  final circle = find.descendant(
    of: button,
    matching: find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == Sp.roundButton && w.height == 44,
    ),
  );
  return tester.getRect(circle);
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('the gap between the box and the circle is 2 dp per side', () {
    expect(Sp.roundButtonInset, 2);
    expect(Sp.headerInsets.left, Sp.page - 2);
    expect(Sp.headerInsets.right, Sp.page);
  });

  testScreen('the app bar reserves the 48 dp box of the back button', (
    tester,
  ) async {
    _phone(tester);
    await pumpFullApp(tester);
    await pushRoute(tester, '/teoria');
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.leadingWidth, Sp.page + Sp.touch + Sp.s);
    expect(find.byType(AptoAppBar), findsOneWidget);
  });

  testScreen('the visible circle of the back button starts at the 16 dp page '
      'margin, like the cards below it', (tester) async {
    _phone(tester);
    await pumpFullApp(tester);
    await pushRoute(tester, '/teoria');
    expect(_circle(tester).left, Sp.page);
    expect(tester.getRect(find.byType(RaisedCard).first).left, Sp.page);
    // The title does not touch the button.
    final box = tester.getRect(find.byType(RoundIconButton).first);
    expect(box.width, Sp.touch);
    expect(
      tester.getRect(find.text('Teoría').first).left,
      greaterThanOrEqualTo(box.right + Sp.s),
    );
  });

  testScreen('the search circle of Teoría and Fallos ends at the right page '
      'margin, as wide as the back button', (tester) async {
    _phone(tester);
    await pumpFullApp(tester);
    for (final route in ['/teoria', '/fallos']) {
      await pushRoute(tester, route);
      expect(find.byType(RoundIconButton), findsNWidgets(2), reason: route);
      final search = _circle(tester, index: 1);
      expect(search.right, 390 - Sp.page, reason: route);
      expect(search.width, Sp.roundButton, reason: route);
      expect(search.top, _circle(tester).top, reason: '$route: same row');
      // The whole 48 dp box stays inside the screen.
      expect(
        tester.getRect(find.byType(RoundIconButton).at(1)).right,
        lessThanOrEqualTo(390),
      );
    }
  });

  testScreen('Ajustes and Fallos use the same alignment', (tester) async {
    _phone(tester);
    await pumpFullApp(tester);
    for (final route in ['/ajustes', '/fallos']) {
      await pushRoute(tester, route);
      expect(_circle(tester).left, Sp.page, reason: route);
    }
  });

  testScreen('the close button of a question and of the exam starts at the '
      'margin too', (tester) async {
    _phone(tester);
    await pumpFullApp(tester);
    await pushRoute(tester, '/tema/1');
    expect(_circle(tester).left, Sp.page);
    await pushRoute(tester, '/simulacro');
    expect(find.byType(RoundIconButton), findsWidgets);
  });

  testScreen('Inicio: the settings circle ends at the page margin', (
    tester,
  ) async {
    _phone(tester);
    await pumpFullApp(tester);
    final circle = _circle(tester);
    expect(circle.right, 390 - Sp.page);
    expect(tester.getRect(find.byType(RaisedCard).first).right, 390 - Sp.page);
    // Still a 48 dp touch target.
    expect(tester.getSize(find.byType(RoundIconButton)), const Size(48, 48));
  });
}
