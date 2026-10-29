import 'package:apto_armas/core/l10n/tema_title.dart';
import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/mock_navigator.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:apto_armas/features/content/domain/question.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/l10n/app_localizations_es.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';

/// iPhone SE (1st gen) size in logical pixels: spec §6 requires the layout to
/// hold here, also with large text.
const Size kSmallScreen = Size(320, 568);

/// 320x568 at device pixel ratio 1, text scale [scale], light or dark.
void useSmallScreen(
  WidgetTester tester, {
  double scale = 1,
  bool dark = false,
}) {
  tester.view.physicalSize = kSmallScreen;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Scrolls [finder] into view and taps it; fails when the tap would miss
/// (something covers it or it is off screen).
Future<void> tapReachable(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0), reason: 'inside the screen');
  expect(rect.right, lessThanOrEqualTo(kSmallScreen.width));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(kSmallScreen.height));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The longest stem in the bank (the worst case for the layout).
Question longestStem(List<Question> bank) =>
    bank.reduce((a, b) => a.stem.length >= b.stem.length ? a : b);

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testScreen('Inicio at 320x568, text x$scale, ${dark ? 'dark' : 'light'}: '
          'no overflow, nothing clipped off-screen', (tester) async {
        useSmallScreen(tester, scale: scale, dark: dark);
        await pumpFullApp(tester);

        // A RenderFlex overflow is reported as a framework exception.
        expect(tester.takeException(), isNull);
        expect(find.text('Ley al Blanco'), findsOneWidget);
        expect(find.text('PROBABILIDAD DE APROBAR'), findsOneWidget);
        // The Teoría shortcut (the real bundle ships the summaries) fits too.
        final teoria = find.text('Teoría');
        expect(teoria, findsOneWidget);
        expect(
          tester.getRect(teoria).right,
          lessThanOrEqualTo(kSmallScreen.width),
        );
        final disclaimer = find.textContaining(
          'App independiente y no oficial',
        );
        expect(disclaimer, findsOneWidget);
        // Horizontally the text fits the screen even at 2x.
        final rect = tester.getRect(disclaimer);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(kSmallScreen.width));
        // Every tema card fits horizontally too.
        final cards = find.byType(TemaCard);
        expect(cards, findsNWidgets(7));
        for (final card in cards.evaluate()) {
          final cardRect = tester.getRect(find.byWidget(card.widget));
          expect(cardRect.left, greaterThanOrEqualTo(0));
          expect(cardRect.right, lessThanOrEqualTo(kSmallScreen.width));
        }
      });
    }
  }

  for (final scale in [1.3, 2.0]) {
    testScreen('every published summary lays out at 320x568, text x$scale, '
        'with every section open', (tester) async {
      useSmallScreen(tester, scale: scale);
      await pumpFullApp(tester);
      for (final id in ['t1', 't2', 't3', 't4', 't5', 't6', 't7', 'practica']) {
        await openRoute(tester, '/teoria/$id');
        // Unfold what starts folded (long tables).
        for (final fold in find.byIcon(Icons.expand_more_rounded).evaluate()) {
          final target = find.byWidget(fold.widget);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: id);
      }
    });
  }

  testScreen('Inicio scrolls when large text does not fit', (tester) async {
    useSmallScreen(tester, scale: 2.0);
    await pumpFullApp(tester);
    expect(tester.takeException(), isNull);
    // The disclaimer is reachable by scrolling even if it starts off-screen.
    await tester.scrollUntilVisible(
      find.textContaining('Guardia Civil'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Guardia Civil'), findsOneWidget);
    expect(find.text('Cuestionario GC nov-2020'), findsOneWidget);
  });

  testScreen('the titles of Inicio are not split at 320x568 with text x2', (
    tester,
  ) async {
    useSmallScreen(tester, scale: 2.0);
    await pumpFullApp(tester);
    expect(tester.takeException(), isNull);
    final l10n = AppLocalizationsEs();
    for (var tema = 1; tema <= 7; tema++) {
      final title = l10n.temaTitle(tema);
      final card = find.text(title);
      expect(card, findsOneWidget, reason: title);
      expectWordsNotSplit(tester, card, title);
    }
  });

  testScreen('the titles of the theory list are not split at 320x568 with '
      'text x2', (tester) async {
    useSmallScreen(tester, scale: 2.0);
    await pumpFullApp(tester);
    await openRoute(tester, '/teoria');
    expect(tester.takeException(), isNull);
    final l10n = AppLocalizationsEs();
    for (var tema = 1; tema <= 7; tema++) {
      final title = l10n.temaTitle(tema);
      final row = find.text(title);
      expect(row, findsOneWidget, reason: title);
      expectWordsNotSplit(tester, row, title);
    }
  });

  testScreen('the titles of the theory reader are not split at 320x568 with '
      'text x2', (tester) async {
    useSmallScreen(tester, scale: 2.0);
    await pumpFullApp(tester);
    final l10n = AppLocalizationsEs();
    for (var tema = 1; tema <= 7; tema++) {
      await openRoute(tester, '/teoria/t$tema');
      expect(tester.takeException(), isNull, reason: 'tema $tema');
      final title = l10n.temaTitle(tema);
      final reader = find.text(title);
      expect(reader, findsOneWidget, reason: 'tema $tema');
      expectWordsNotSplit(tester, reader, title);
      expectWordsInside(tester, reader, title);
    }
    // The AEM has a reader too.
    await openRoute(tester, '/teoria/aem');
    expect(tester.takeException(), isNull);
    const aem = 'Autorización especial para menores (AEM)';
    expect(find.text(aem), findsOneWidget);
    expectWordsNotSplit(tester, find.text(aem), aem);
    expectWordsInside(tester, find.text(aem), aem);
  });

  group('the titles keep their size while they fit', () {
    // The size of the style of a row title, with the scale of the user.
    double rowTitleSize(double scale) =>
        AppTheme.light().extension<AptoTypography>()!.rowTitle.fontSize! * scale;

    for (final scale in [1.0, 1.3]) {
      testScreen('the titles of Inicio are not shrunk at 320x568 with text '
          'x$scale', (tester) async {
        useSmallScreen(tester, scale: scale);
        await pumpFullApp(tester);
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizationsEs();
        for (var tema = 1; tema <= 7; tema++) {
          final title = l10n.temaTitle(tema);
          final card = find.text(title);
          expect(card, findsOneWidget, reason: title);
          expect(
            effectiveFontSize(tester, card),
            closeTo(rowTitleSize(scale), 0.01),
            reason: title,
          );
        }
      });

      testScreen('the titles of the theory list are not shrunk at 320x568 '
          'with text x$scale', (tester) async {
        useSmallScreen(tester, scale: scale);
        await pumpFullApp(tester);
        await openRoute(tester, '/teoria');
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizationsEs();
        for (var tema = 1; tema <= 7; tema++) {
          final title = l10n.temaTitle(tema);
          final row = find.text(title);
          expect(row, findsOneWidget, reason: title);
          expect(
            effectiveFontSize(tester, row),
            closeTo(rowTitleSize(scale), 0.01),
            reason: title,
          );
        }
      });
    }
  });

  group('practice screen with the longest stem', () {
    for (final scale in [1.3, 2.0]) {
      testScreen('options A, B and C are tappable at text x$scale', (
        tester,
      ) async {
        useSmallScreen(tester, scale: scale);
        await pumpFullApp(tester);
        final bank = await bankOf(tester);
        final longest = longestStem(bank);
        await pushRoute(tester, '/tema/${longest.tema}');
        // Tema 6 opens at t6-001, the longest stem of the bank.
        expect(find.text(longest.stem), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Option C: reachable by scrolling, and a tap lands on it.
        await tapReachable(tester, find.byType(OptionCard).at(2));
        expect(find.text('Siguiente'), findsOneWidget);
        expect(
          optionStates(tester).where((s) => s != OptionState.idle),
          hasLength(greaterThan(0)),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testScreen('"Siguiente" stays on screen with a long explanation', (
      tester,
    ) async {
      useSmallScreen(tester, scale: 1.3);
      final json = realQuestionsJson();
      final long = json.firstWhere((q) => q['id'] == 't6-001');
      long['explanation'] = {
        'es': List.filled(
          14,
          'Texto largo de explicación para comprobar que la hoja se desplaza.',
        ).join(' '),
      };
      long['article'] = 'Art. 96 del Reglamento de Armas (RD 137/1993)';
      await pumpFullApp(tester, bundle: FakeAssetBundle.edition(json));
      await pushRoute(tester, '/tema/6');

      await tapReachable(tester, find.byType(OptionCard).at(2));
      expect(find.textContaining('Art. 96'), findsOneWidget);
      final next = find.widgetWithText(FilledButton, 'Siguiente');
      final rect = tester.getRect(next);
      expect(rect.bottom, lessThanOrEqualTo(kSmallScreen.height));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);

      // The long explanation scrolls under the pill: its end (the article
      // chip) can be brought clear of it.
      final chip = find.textContaining('Art. 96');
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(chip).bottom,
        lessThanOrEqualTo(tester.getRect(next).top),
        reason: 'nothing is trapped behind the floating pill',
      );

      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('2 de 64 pendientes'), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testScreen('long notice + explanation at text x$scale: no overflow, '
          '"Siguiente" reachable', (tester) async {
        useSmallScreen(tester, scale: scale);
        final json = realQuestionsJson();
        final q = json.firstWhere((q) => q['id'] == 't6-001');
        const noticeStart =
            'Ojo: el cuestionario dice que la licencia es válida durante un '
            'plazo que ya no es el vigente; tras la reforma de 2023 el '
            'artículo 96 del Reglamento de Armas establece otro distinto.';
        q['notice'] = {
          'es':
              '$noticeStart ${List.filled(4, 'Texto adicional del aviso.').join(' ')}',
        };
        q['flags'] = ['discrepancia_reforma_2023'];
        q['explanation'] = {
          'es': List.filled(
            8,
            'Texto largo de explicación para comprobar que todo se desplaza.',
          ).join(' '),
        };
        q['article'] = 'Art. 96 del Reglamento de Armas (RD 137/1993)';
        await pumpFullApp(tester, bundle: FakeAssetBundle.edition(json));
        await pushRoute(tester, '/tema/6');

        await tapReachable(tester, find.byType(OptionCard).at(2));
        expect(tester.takeException(), isNull);
        expect(find.text('Aviso: cambio en la norma'), findsOneWidget);
        expect(find.textContaining(noticeStart), findsOneWidget);

        // The callout fits the screen horizontally and "Siguiente" floats
        // inside it.
        final callout = find.text('Aviso: cambio en la norma');
        await tester.ensureVisible(callout);
        await tester.pumpAndSettle();
        final rect = tester.getRect(callout);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(kSmallScreen.width));
        final body = tester.getRect(find.textContaining(noticeStart));
        expect(body.right, lessThanOrEqualTo(kSmallScreen.width));
        final next = find.widgetWithText(FilledButton, 'Siguiente');
        expect(
          tester.getRect(next).bottom,
          lessThanOrEqualTo(kSmallScreen.height),
        );

        // Everything below the notice scrolls clear of the pill.
        final chip = find.textContaining('Art. 96');
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(chip).bottom,
          lessThanOrEqualTo(tester.getRect(next).top),
          reason: 'nothing is trapped behind the floating pill',
        );
        expect(tester.takeException(), isNull);

        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text('2 de 64 pendientes'), findsOneWidget);
        // The next question has no notice.
        expect(find.text('Aviso: cambio en la norma'), findsNothing);
      });
    }

    testScreen('answered question at text x2: Siguiente is reachable', (
      tester,
    ) async {
      useSmallScreen(tester, scale: 2.0);
      await pumpFullApp(tester);
      await pushRoute(tester, '/tema/6');
      await tapReachable(tester, find.byType(OptionCard).at(0));
      expect(tester.takeException(), isNull);
      await tapReachable(
        tester,
        find.widgetWithText(FilledButton, 'Siguiente'),
      );
      expect(find.text('2 de 64 pendientes'), findsOneWidget);
    });
  });

  group('mock screens with the longest stems', () {
    /// Stores an unfinished mock made of the 20 longest stems of the bank.
    Future<int> longMock(WidgetTester tester) async {
      final bank = await bankOf(tester);
      final longest = [...bank]
        ..sort((a, b) => b.stem.length.compareTo(a.stem.length));
      return containerOf(tester)
          .read(mockRepositoryProvider)
          .start(longest.take(20).toList(), timed: true, startedAt: kTestNow);
    }

    for (final scale in [1.3, 2.0]) {
      testScreen('question, bar, navigator and dialog at text x$scale', (
        tester,
      ) async {
        useSmallScreen(tester, scale: scale);
        await pumpFullApp(tester);
        final id = await longMock(tester);
        await pushRoute(tester, '/simulacro/$id');
        expect(tester.takeException(), isNull);
        expect(find.text('1 / 20'), findsOneWidget);
        expect(find.text('Quedan 20:00'), findsOneWidget);

        // The three options can be picked (scrolling when needed).
        for (var i = 0; i < 3; i++) {
          await tapReachable(tester, find.byType(OptionCard).at(i));
          expect(optionStates(tester)[i], OptionState.selected);
        }

        // The bar buttons are on screen and work.
        await tapReachable(tester, find.text('Siguiente'));
        expect(find.text('2 / 20'), findsOneWidget);
        await tapReachable(tester, find.text('Anterior'));
        expect(find.text('1 / 20'), findsOneWidget);

        // The navigator: all 20 cells fit and the last one is tappable.
        await tapReachable(tester, find.text('Preguntas'));
        expect(find.byType(MockNavigator), findsOneWidget);
        final cell20 = find.descendant(
          of: find.byType(MockNavigator),
          matching: find.text('20'),
        );
        await tapReachable(tester, cell20);
        expect(find.text('20 / 20'), findsOneWidget);

        // Entregar: the dialog fits and can be dismissed.
        await tapReachable(
          tester,
          find.widgetWithText(FilledButton, 'Entregar'),
        );
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tapReachable(tester, find.text('Seguir'));
        expect(find.byType(AlertDialog), findsNothing);
      });
    }

    testScreen('result with 20 failed long questions at text x1.3', (
      tester,
    ) async {
      useSmallScreen(tester, scale: 1.3);
      await pumpFullApp(tester);
      final id = await longMock(tester);
      await pushRoute(tester, '/simulacro/$id');
      await tapReachable(tester, find.widgetWithText(FilledButton, 'Entregar'));
      await tapReachable(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Entregar'),
        ),
      );
      expect(find.text('NO APTO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Review of one failed question.
      await tapReachable(tester, find.textContaining('1. ').first);
      expect(find.text('Revisión'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final q = (await containerOf(
        tester,
      ).read(mockOutcomeProvider(id).future))!.questions.first;
      expect(find.text(q.stem), findsOneWidget);
    });
  });

  testScreen('Fallos and the intro fit at 320x568 text x1.3', (tester) async {
    useSmallScreen(tester, scale: 1.3);
    await pumpFullApp(tester);
    await pushRoute(tester, '/fallos');
    expect(tester.takeException(), isNull);
    expect(find.text('No tienes fallos pendientes'), findsOneWidget);
    await pushRoute(tester, '/simulacro');
    expect(tester.takeException(), isNull);
    await tapReachable(tester, find.text('Empezar'));
    expect(tester.takeException(), isNull);
    expect(find.text('1 / 20'), findsOneWidget);
  });
}
