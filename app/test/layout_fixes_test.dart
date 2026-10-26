import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:apto_armas/core/widgets/option_card.dart';
import 'package:apto_armas/core/widgets/tema_card.dart';
import 'package:apto_armas/features/theory/domain/theory.dart';
import 'package:apto_armas/features/theory/presentation/theory_diagrams.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/play_mock_support.dart';
import 'support/screen_support.dart';

/// Layout and screen-reader fixes of the manual tests of 0.6.0
/// (manual review of 0.6.0, batch 1: R-03 to R-12).

void _small(WidgetTester tester, {required double scale}) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void main() {
  group('R-03 the caption of a sequence is drawn', () {
    const caption = 'Cada vez que coges un arma';
    const steps = DiagramBlock(
      kind: TheoryDiagramKind.secuencia,
      caption: caption,
      items: ['Comprueba que está descargada', 'Apunta a un lugar seguro'],
    );

    testWidgets('above the steps, and spoken once with the description', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const Scaffold(body: TheoryDiagram(block: steps)));
      expect(find.text(caption), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(caption)).dy,
        lessThan(tester.getTopLeft(find.text('1')).dy),
      );
      // The screen reader gets it inside the block's label, not twice.
      expect(find.bySemanticsLabel(RegExp(caption)), findsOneWidget);
      handle.dispose();
    });
  });

  group('R-10 the gallery labels never touch', () {
    const labels = GaleriaTiroLabels(
      puesto: 'Puesto de tiro',
      firingLine: 'Línea de tiro',
      target: 'Blanco a 25 m',
      distance: '25 m',
      safeZone: 'Zona segura',
    );

    for (final scale in [1.0, 1.3, 2.0]) {
      for (final width in [248.0, 288.0, 360.0]) {
        test('x$scale in a panel $width dp wide', () {
          final style = const TextStyle(
            fontFamily: 'PublicSans',
            fontSize: 12,
            height: 1.4,
          );
          final painter = GaleriaTiroPainter(
            colors: AptoColors.light,
            labelStyle: style,
            textScaler: TextScaler.linear(scale),
            labels: labels,
          );
          final height = painter.heightFor(
            width,
            TextScaler.linear(scale).scale(TheoryDiagram.baseHeight),
          );
          final rects = painter.labelRects(Size(width, height));
          final names = rects.keys.toList();
          for (var i = 0; i < names.length; i++) {
            expect(rects[names[i]]!.top, greaterThanOrEqualTo(0));
            expect(rects[names[i]]!.bottom, lessThanOrEqualTo(height));
            for (var j = i + 1; j < names.length; j++) {
              expect(
                rects[names[i]]!.overlaps(rects[names[j]]!),
                isFalse,
                reason: '${names[i]} touches ${names[j]}: $rects',
              );
            }
          }
          // Safe zone sits clear of the firing line label by a few dp.
          expect(
            rects['firing']!.top - rects['safe']!.bottom,
            greaterThanOrEqualTo(0),
          );
        });
      }
    }
  });

  group('R-04 a long tema title is not cut', () {
    testWidgets('TemaCard shows every line at x2', (tester) async {
      _small(tester, scale: 2);
      const title =
          'Armas de colección, definiciones, historia, calibres y munición';
      await pumpApp(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: TemaCard(tema: 7, title: title, mastery: 0.5, mistakes: 0),
          ),
        ),
        textScale: 2,
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      expect(tester.widget<Text>(find.text(title)).maxLines, isNull);
    });
  });

  group('R-05 the tema row of the result', () {
    // At 411 dp and x2 the title fits whole once it has the full width of
    // the row (the figure moves under it, next to the bar). At 320 dp and x2
    // the word is wider than the card whatever is done: only no overflow.
    testScreen('keeps «Funcionamiento» whole at 411 dp and x2', (tester) async {
      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFullApp(tester);
      final mock = await playMock(tester, right: 12, wrong: 8, submit: true);
      await pushRoute(tester, '/simulacro/${mock.id}/resultado');
      final title = find.textContaining('Funcionamiento');
      await tester.ensureVisible(title.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final element in title.evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final text = paragraph.text.toPlainText();
        final word = RegExp(r'Funcionamiento').firstMatch(text)!;
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        );
        expect({for (final b in boxes) b.top.round()}, hasLength(1));
        expect(
          boxes.every((b) => b.right <= paragraph.size.width + 0.5),
          isTrue,
        );
      }
    });
  });

  group('the result at 320 dp and x2', () {
    testScreen('has no overflow (ring figure scales down)', (tester) async {
      _small(tester, scale: 2);
      await pumpFullApp(tester);
      final mock = await playMock(tester, right: 12, wrong: 8, submit: true);
      await pushRoute(tester, '/simulacro/${mock.id}/resultado');
      await tester.ensureVisible(find.textContaining('Funcionamiento').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('R-06 «Continuar» with the count under it is centred', () {
    testScreen('both lines centred at 320 dp and x2', (tester) async {
      _small(tester, scale: 2);
      await pumpFullApp(tester);
      final label = find.text('Continuar');
      final count = find.textContaining('preguntas para hoy');
      expect(label, findsOneWidget);
      expect(count, findsOneWidget);
      // Stacked: the count is under the label.
      expect(
        tester.getTopLeft(count).dy,
        greaterThan(tester.getTopLeft(label).dy),
      );
      expect(tester.widget<Text>(label).textAlign, TextAlign.center);
      expect(tester.widget<Text>(count).textAlign, TextAlign.center);
      expect(
        tester.getCenter(label).dx,
        closeTo(tester.getCenter(count).dx, 1),
      );
    });
  });

  group('R-09 the scrollbar is visible on the dark card', () {
    test('thumb colour is outlineStrong in both themes', () {
      for (final (theme, colors) in [
        (AppTheme.light(), AptoColors.light),
        (AppTheme.dark(), AptoColors.dark),
      ]) {
        expect(
          theme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{}),
          colors.outlineStrong,
        );
      }
    });
  });

  group('R-11 spoken labels', () {
    testScreen('the progress bar says «Pregunta 1 de N»', (tester) async {
      final handle = tester.ensureSemantics();
      _small(tester, scale: 1);
      await pumpFullApp(tester);
      await pushRoute(tester, '/tema/1');
      expect(find.bySemanticsLabel(RegExp(r'^Pregunta 1 de \d+$')), findsOne);
      handle.dispose();
    });

    testScreen('the result ring says «12 aciertos de 20»', (tester) async {
      final handle = tester.ensureSemantics();
      _small(tester, scale: 1);
      await pumpFullApp(tester);
      final mock = await playMock(tester, right: 12, wrong: 8, submit: true);
      await pushRoute(tester, '/simulacro/${mock.id}/resultado');
      expect(find.bySemanticsLabel('12 aciertos de 20'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a judged option does not read a double full stop', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: OptionCard(
            letter: 'B',
            text: 'Es una pistola semiautomática.',
            state: OptionState.incorrect,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Opción B: Es una pistola semiautomática. Incorrecta',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'\.\.')), findsNothing);
      handle.dispose();
    });
  });
}
