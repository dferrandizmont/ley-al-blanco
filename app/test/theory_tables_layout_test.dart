import 'dart:convert';

import 'package:apto_armas/core/theme/spacing.dart';
import 'package:apto_armas/features/theory/domain/theory.dart';
import 'package:apto_armas/features/theory/presentation/theory_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';

/// Every table of the real `teoria.json`.
List<TableBlock> _publishedTables() {
  final bank = TheoryBank.fromJson(
    jsonDecode(utf8.decode(realTheoryBytes())) as Map<String, dynamic>,
  );
  return [
    for (final doc in bank.docs)
      for (final section in doc.sections)
        ...section.blocks.whereType<TableBlock>(),
  ];
}

/// The words of [paragraph] that are drawn over more than one line: a word
/// that was cut in the middle because its column is too narrow. A line may
/// break after a hyphen («dum-» / «dum»), so the parts of a hyphenated word
/// count as words of their own.
List<String> _splitWords(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  final split = <String>[];
  for (final word in RegExp(r'[^\s-]+').allMatches(text)) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    final tops = {for (final box in boxes) box.top.round()};
    final overflows = boxes.any(
      (box) => box.right > paragraph.size.width + 0.5,
    );
    if (tops.length > 1 || overflows) split.add(word.group(0)!);
  }
  return split;
}

void main() {
  final tables = _publishedTables();

  test('the real teoria.json has tables to check', () {
    expect(tables.length, greaterThan(10));
  });

  group('no word of any published table is split', () {
    // 320 is the iPhone SE; 411 a common Android phone. The inset is what the
    // reader leaves around a table: none (the widest it can get) and the real
    // one (page margin + card padding on both sides).
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final width in [320.0, 411.0]) {
        for (final inset in [0.0, Sp.page + Sp.cardPad]) {
          testWidgets('x$scale, $width dp wide, $inset dp inset', (
            tester,
          ) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);
            final broken = <String>[];
            for (final table in tables) {
              await pumpApp(
                tester,
                Scaffold(
                  body: Padding(
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    child: SingleChildScrollView(
                      child: TheoryTable(table: table),
                    ),
                  ),
                ),
                textScale: scale,
              );
              expect(tester.takeException(), isNull);
              final paragraphs = find
                  .descendant(
                    of: find.byType(TheoryTable),
                    matching: find.byType(RichText),
                  )
                  .evaluate()
                  .map((e) => e.renderObject)
                  .whereType<RenderParagraph>();
              for (final paragraph in paragraphs) {
                broken.addAll(_splitWords(paragraph));
              }
              // When the columns do not fit the table scrolls, visibly.
              final sideways = find
                  .descendant(
                    of: find.byType(TheoryTable),
                    matching: find.byType(SingleChildScrollView),
                  )
                  .evaluate()
                  .isNotEmpty;
              expect(
                find.descendant(
                  of: find.byType(TheoryTable),
                  matching: find.byType(Scrollbar),
                ),
                sideways ? findsOneWidget : findsNothing,
              );
            }
            expect(broken, isEmpty, reason: 'split words: $broken');
          });
        }
      }
    }
  });

  group('columnWidths', () {
    const table = TableBlock(
      headers: ['Tipo', 'Qué es'],
      rows: [
        ['Automática', 'Dispara en ráfagas mientras se mantiene el gatillo'],
        ['Semiautomática', 'Un disparo por pulsación'],
      ],
    );

    // 8 dp per character, whatever the style.
    double measure(String text, int column, bool header) => text.length * 8;

    test('fits: the widths add up to the available width', () {
      final layout = TheoryTable.columnWidths(
        table: table,
        maxWidth: 400,
        textScaler: TextScaler.noScaling,
        measure: measure,
      );
      expect(layout.scrolls, isFalse);
      expect(layout.widths.reduce((a, b) => a + b), closeTo(400, 0.001));
    });

    test('a column is never narrower than its longest word', () {
      // Longest words: «Semiautomática» (14 chars = 112 dp + padding) and
      // «pulsación»/«mientras»/«ráfagas» in the second column.
      for (final maxWidth in [260.0, 300.0, 400.0, 900.0]) {
        final layout = TheoryTable.columnWidths(
          table: table,
          maxWidth: maxWidth,
          textScaler: TextScaler.noScaling,
          measure: measure,
        );
        expect(layout.widths[0], greaterThanOrEqualTo(14 * 8 + 2 * Sp.m));
        expect(layout.widths[1], greaterThanOrEqualTo(9 * 8 + 2 * Sp.m));
      }
    });

    test('the column with long texts gets more room than the short one', () {
      final layout = TheoryTable.columnWidths(
        table: table,
        maxWidth: 400,
        textScaler: TextScaler.noScaling,
        measure: measure,
      );
      expect(layout.widths[1], greaterThan(layout.widths[0]));
    });

    test('scrolls when the narrowest columns do not fit', () {
      final layout = TheoryTable.columnWidths(
        table: table,
        maxWidth: 200,
        textScaler: TextScaler.noScaling,
        measure: measure,
      );
      expect(layout.scrolls, isTrue);
      expect(layout.widths.reduce((a, b) => a + b), greaterThan(200));
    });
  });
}
