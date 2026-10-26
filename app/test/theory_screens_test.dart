import 'dart:convert';

import 'package:apto_armas/core/widgets/action_card.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/core/widgets/notice_callout.dart';
import 'package:apto_armas/features/theory/domain/theory.dart';
import 'package:apto_armas/features/theory/presentation/theory_blocks.dart';
import 'package:apto_armas/features/theory/presentation/theory_diagrams.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/theory_support.dart';

/// A build without theory: the manifest has no `teoria_sha256` and there is no
/// `teoria.json`.
final _noTheory = theoryBundle(
  includeManifestField: false,
  includeAsset: false,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// The app with the theory fixture. The user owns the full version unless
/// [free] (then the real entitlement controller over a fresh fake store).
Future<void> _pump(WidgetTester tester) async {
  _phone(tester);
  await pumpFullApp(tester, bundle: theoryBundle());
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testScreen('theory cards open through accessibility tap actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(tester);
      for (final (title, route) in [
        ('La prueba práctica', '/teoria/practica'),
        ('Funcionamiento y seguridad', '/teoria/t1'),
      ]) {
        await openRoute(tester, '/teoria');
        await tester.ensureVisible(find.text(title));
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.text(title));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(locationOf(tester), route);
      }
    } finally {
      handle.dispose();
    }
  });

  group('Inicio entry', () {
    testScreen('shows Teoría and opens the list when the theory is there', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Teoría'), findsOneWidget);
      expect(find.text('Resúmenes y prueba práctica'), findsOneWidget);
      await _tap(tester, find.widgetWithText(ActionCard, 'Teoría'));
      expect(locationOf(tester), '/teoria');
    });

    testScreen('is hidden when the build has no theory', (tester) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: _noTheory);
      expect(find.text('Teoría'), findsNothing);
      // Simulacro, Fallos, Cifras y plazos and Tarjetas de cifras: no Teoría tile.
      expect(find.byType(ActionCard), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testScreen('is hidden when the checksum does not match', (tester) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: theoryBundle(wrongSha: 'b' * 64));
      expect(find.text('Teoría'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('list', () {
    testScreen('the title of a tema is the official one from the ARB, not the '
        "document's own", (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria');
      // The fixture calls tema 4 «Resumen del tema 4».
      expect(find.text('Resumen del tema 4'), findsNothing);
      expect(
        find.text('Documentación y licencias, Tarjeta Europea'),
        findsOneWidget,
      );
      await _tap(
        tester,
        find.text('Documentación y licencias, Tarjeta Europea'),
      );
      expect(find.text('TEMA 4 · TEORÍA'), findsOneWidget);
      expect(
        find.text('Documentación y licencias, Tarjeta Europea'),
        findsOneWidget,
      );
      expect(find.text('Resumen del tema 4'), findsNothing);
    });

    testScreen('tapping a free summary opens it', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria');
      await _tap(tester, find.text('Funcionamiento y seguridad'));
      expect(locationOf(tester), '/teoria/t1');
    });

    testScreen('the practical test is free for a free user', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria');
      await _tap(tester, find.text('La prueba práctica'));
      expect(locationOf(tester), '/teoria/practica');
      expect(find.text('La prueba práctica de tiro'), findsOneWidget);
    });

    testScreen('without theory the list is an empty state, not a crash', (
      tester,
    ) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: _noTheory);
      await openRoute(tester, '/teoria');
      expect(find.text('La teoría no está disponible'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('routes', () {
    testScreen('a deep link to tema 1 and to the practica is open', (
      tester,
    ) async {
      await _pump(tester);
      for (final tema in [1, 2, 3]) {
        await openRoute(tester, '/teoria/t$tema');
        expect(locationOf(tester), '/teoria/t$tema');
      }
      await openRoute(tester, '/teoria/practica');
      expect(locationOf(tester), '/teoria/practica');
    });

    testScreen('a paid user opens any summary', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t5');
      expect(locationOf(tester), '/teoria/t5');
      expect(find.text('Régimen sancionador'), findsOneWidget);
    });

    testScreen('an unknown id falls back to the list', (tester) async {
      await _pump(tester);
      for (final bad in ['t8', 't0', 'xyz', 'T1']) {
        await openRoute(tester, '/teoria/$bad');
        expect(locationOf(tester), '/teoria', reason: bad);
      }
    });

    testScreen('a deep link without theory shows the empty state', (
      tester,
    ) async {
      _phone(tester);
      await pumpFullApp(tester, bundle: _noTheory);
      await openRoute(tester, '/teoria/t1');
      expect(find.text('La teoría no está disponible'), findsOneWidget);
    });
  });

  group('reader', () {
    testScreen('renders the header and every kind of block', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t1');

      expect(find.text('TEMA 1 · TEORÍA'), findsOneWidget);
      expect(find.text('Funcionamiento y seguridad'), findsOneWidget);
      expect(find.text('Resumen de t1.'), findsOneWidget);

      // p, list, table, key, notice of the first (open) section.
      expect(
        find.text('Las armas se distinguen por la recarga.'),
        findsOneWidget,
      );
      expect(find.text('Automática: varios disparos'), findsOneWidget);
      expect(find.byType(TheoryTable), findsOneWidget);
      expect(find.text('Tipos de arma'), findsOneWidget);
      expect(find.text('Tipo'), findsOneWidget);
      expect(find.text('Se recarga sola; ráfaga'), findsOneWidget);
      expect(find.text('Clave para el examen'), findsOneWidget);
      expect(find.text('la definición de arma.'), findsOneWidget);
      expect(find.byType(NoticeCallout), findsOneWidget);
      expect(find.text('Aviso: cambio en la norma'), findsOneWidget);
      // Two chips in the first section, one in the last; the folded one hides its.
      expect(find.byType(ArticleChip), findsNWidgets(3));
      expect(find.text('Art. 2.5 RD 137/1993'), findsOneWidget);
    });

    testScreen('the diagram section starts folded and unfolds', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t1');

      expect(find.byType(TheoryDiagram), findsNothing);
      expect(find.text('Anexo II Resolución 1998'), findsNothing);

      await _tap(tester, find.text('Esquemas de seguridad'));
      expect(find.byType(TheoryDiagram), findsNWidgets(3));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Galería a 25 metros'), findsOneWidget);
      expect(find.text('Comprueba que está descargada'), findsOneWidget);
      expect(find.text('Anexo II Resolución 1998'), findsOneWidget);
      // The numbered steps of the sequence.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testScreen('tapping a section title folds and unfolds it', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t1');
      const body = 'Limpia el arma después de usarla.';
      expect(find.text(body), findsOneWidget);

      await _tap(tester, find.text('Mantenimiento'));
      expect(find.text(body), findsNothing);
      expect(find.byIcon(Icons.expand_more_rounded), findsNWidgets(2));

      await _tap(tester, find.text('Mantenimiento'));
      expect(find.text(body), findsOneWidget);
    });

    testScreen('section headers announce their state to screen readers', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t1');
      final handle = tester.ensureSemantics();
      await tester.ensureVisible(find.text('Mantenimiento'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Mantenimiento')),
        matchesSemantics(
          label: 'Mantenimiento',
          hint: 'Toca para plegar',
          isButton: true,
          isHeader: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      await tester.ensureVisible(find.text('Esquemas de seguridad'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Esquemas de seguridad')),
        matchesSemantics(
          label: 'Esquemas de seguridad',
          hint: 'Toca para desplegar',
          isButton: true,
          isHeader: true,
          hasExpandedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testScreen('the diagrams describe themselves to screen readers', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t1');
      await _tap(tester, find.text('Esquemas de seguridad'));
      final handle = tester.ensureSemantics();

      Future<void> show(Finder diagram) async {
        await tester.ensureVisible(diagram);
        await tester.pumpAndSettle();
      }

      final diagrams = find.byType(TheoryDiagram);
      await show(diagrams.at(0));
      expect(
        find.bySemanticsLabel(
          RegExp(r'^Esquema de la galería de tiro.*Galería a 25 metros$'),
        ),
        findsOneWidget,
      );
      await show(diagrams.at(1));
      expect(
        find.bySemanticsLabel(RegExp(r'^Esquema del sector de tiro')),
        findsOneWidget,
      );
      await show(diagrams.at(2));
      expect(find.bySemanticsLabel('Secuencia de 2 pasos'), findsOneWidget);
      expect(find.bySemanticsLabel('Paso 2: Apunta a la zona'), findsOneWidget);
      handle.dispose();
    });

    testScreen('"Practicar este tema" opens the practice of that tema', (
      tester,
    ) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t4');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Practicar este tema'),
      );
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/tema/4');
    });

    testScreen('a free user practises tema 1 from its summary', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/t1');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Practicar este tema'),
      );
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/tema/1');
    });

    testScreen('the practica has no practise button', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria/practica');
      expect(find.text('TEORÍA · PRUEBA PRÁCTICA'), findsOneWidget);
      expect(find.text('Practicar este tema'), findsNothing);
    });

    testScreen('back returns to the list', (tester) async {
      await _pump(tester);
      await openRoute(tester, '/teoria');
      await _tap(tester, find.text('Categorías de armas'));
      expect(locationOf(tester), '/teoria/t2');
      routerOf(tester).pop();
      await tester.pumpAndSettle();
      expect(locationOf(tester), '/teoria');
    });
  });

  group('small phone and large text', () {
    testScreen('the reader lays out at 320 x 568 with text x1.3', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFullApp(tester, bundle: theoryBundle());
      await openRoute(tester, '/teoria/t1');
      await _tap(tester, find.text('Esquemas de seguridad'));
      expect(tester.takeException(), isNull);
      await openRoute(tester, '/teoria');
      expect(tester.takeException(), isNull);
    });
  });

  group('blocks at large text sizes', () {
    Future<void> pumpAt(
      WidgetTester tester,
      Widget child, {
      required double scale,
      double width = 320,
    }) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpApp(tester, Scaffold(body: child), textScale: scale);
    }

    const narrow = TableBlock(
      headers: ['Tipo', 'Cómo funciona', 'Ejemplo', 'Notas'],
      rows: [
        ['Automática', 'Se recarga sola; ráfaga', 'Fusil', 'Prohibida'],
      ],
    );
    const wide = TableBlock(
      headers: ['Tipo', 'Cómo funciona'],
      rows: [
        ['Automática', 'Se recarga sola'],
      ],
    );

    testWidgets('a table that does not fit scrolls sideways with a scrollbar', (
      tester,
    ) async {
      await pumpAt(tester, const TheoryTable(table: narrow), scale: 1);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('a table that fits has no scroll and no scrollbar', (
      tester,
    ) async {
      await pumpAt(tester, const TheoryTable(table: wide), scale: 1);
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('the minimum column width grows with the text scale', (
      tester,
    ) async {
      // The longest words fit side by side at x1 but not at x2, where the
      // table keeps their width and scrolls instead of splitting them.
      const words = TableBlock(
        headers: ['Documentación', 'Autorización'],
        rows: [
          ['Licencia', 'Guardia Civil'],
        ],
      );
      await pumpAt(tester, const TheoryTable(table: words), scale: 1);
      expect(find.byType(Scrollbar), findsNothing);

      await pumpAt(tester, const TheoryTable(table: words), scale: 2);
      expect(find.byType(Scrollbar), findsOneWidget);
      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(scroll.scrollDirection, Axis.horizontal);
      final content = tester.getSize(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(content.width, greaterThan(320));
    });

    testWidgets('no cell of any published table overflows at 320 x1.3', (
      tester,
    ) async {
      final bank = TheoryBank.fromJson(
        jsonDecode(utf8.decode(realTheoryBytes())) as Map<String, dynamic>,
      );
      final tables = [
        for (final doc in bank.docs)
          for (final section in doc.sections)
            ...section.blocks.whereType<TableBlock>(),
      ];
      expect(tables, isNotEmpty);
      for (final table in tables) {
        await pumpAt(
          tester,
          SingleChildScrollView(child: TheoryTable(table: table)),
          scale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final cells = <String>{
          ...table.headers,
          for (final r in table.rows) ...r,
        };
        for (final text in cells) {
          for (final element in find.text(text).evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            // Word by word: a wrapped line's trailing space is not content.
            for (final word in RegExp(r'\S+').allMatches(text)) {
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: word.start, extentOffset: word.end),
              );
              for (final box in boxes) {
                expect(
                  box.right,
                  lessThanOrEqualTo(paragraph.size.width + 0.5),
                  reason: '"${word.group(0)}" overflows its cell',
                );
              }
            }
          }
        }
      }
    });

    testWidgets('the step circle grows with the text so 10 fits at x2', (
      tester,
    ) async {
      final steps = DiagramBlock(
        kind: TheoryDiagramKind.secuencia,
        items: [for (var i = 1; i <= 10; i++) 'Paso $i'],
      );
      await pumpAt(
        tester,
        SingleChildScrollView(child: TheoryDiagram(block: steps)),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      final number = tester.getSize(find.text('10'));
      final circle = tester.getSize(
        find
            .ancestor(of: find.text('10'), matching: find.byType(DecoratedBox))
            .first,
      );
      expect(circle.width, greaterThanOrEqualTo(number.width));
      expect(circle.height, greaterThanOrEqualTo(number.height));
      expect(circle.width, 64);
    });

    testWidgets('the bullet dot follows the first line when text grows', (
      tester,
    ) async {
      const list = ListBlock(['Una línea', 'Otra']);
      double dotOffset(Finder dot, Finder text) =>
          tester.getCenter(dot).dy - tester.getCenter(text).dy;

      for (final scale in [1.0, 2.0]) {
        await pumpAt(tester, const TheoryBlockView(block: list), scale: scale);
        final text = find.text('Una línea');
        final dot = find.descendant(
          of: find.ancestor(of: text, matching: find.byType(Row)).first,
          matching: find.byType(DecoratedBox),
        );
        expect(dotOffset(dot, text).abs(), lessThan(1.0), reason: 'x$scale');
      }
    });
  });
}
