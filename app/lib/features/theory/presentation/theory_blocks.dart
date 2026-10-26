import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/article_chip.dart';
import '../../../core/widgets/notice_callout.dart';
import '../../../core/widgets/raised_card.dart';
import '../domain/theory.dart';
import 'theory_diagrams.dart';

/// Draws one [TheoryBlock] of a section: paragraph, list, table, «Lo que más
/// cae» box, reform notice, diagram or list of glossary terms.
class TheoryBlockView extends StatelessWidget {
  const TheoryBlockView({super.key, required this.block});

  final TheoryBlock block;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      ParagraphBlock(:final text) => Text(text, style: context.typo.body),
      ListBlock(:final items) => _BulletList(items: items),
      final TableBlock table => TheoryTable(table: table),
      final KeyBlock key => _KeyBox(block: key),
      NoticeBlock(:final text) => NoticeCallout(text: text),
      final DiagramBlock diagram => TheoryDiagram(block: diagram),
      TermsBlock(:final items) => TheoryTerms(items: items),
    };
  }
}

/// A list of definitions (the glossary): per entry the term in bold, its
/// definition and, when there is one, the article chip. Entries are separated
/// by a hairline; a screen reader reads each one as a single item
/// («term, definition, source article»).
class TheoryTerms extends StatelessWidget {
  const TheoryTerms({super.key, required this.items});

  final List<TermItem> items;

  @override
  Widget build(BuildContext context) {
    final typo = context.typo;
    final term = AptoTypography.weight(typo.body, 700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Sp.m),
              child: CardDivider(),
            ),
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.term, style: term),
                const SizedBox(height: Sp.xs),
                Text(item.text, style: typo.body),
                if (item.article != null) ...[
                  const SizedBox(height: Sp.s),
                  ArticleChip(article: item.article!),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A bulleted list: a small brand-green dot and the text, one row per item.
class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.typo.body;
    // Centres the dot on the first line of text (which grows with the text
    // scale, unlike the dot).
    final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
    final dotTop = (fontSize * style.height! - Sp.s) / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) const SizedBox(height: Sp.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Padding(
                  padding: EdgeInsets.only(top: dotTop),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: Sp.s),
                  ),
                ),
              ),
              const SizedBox(width: Sp.m),
              Expanded(child: Text(item, style: style)),
            ],
          ),
        ],
      ],
    );
  }
}

/// The «Clave para el examen» box: a star, the title and the text, on the tinted
/// brand container (not the amber of a reform notice).
class _KeyBox extends StatelessWidget {
  const _KeyBox({required this.block});

  final KeyBlock block;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: Rad.optionRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Sp.l),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.star_rounded,
              size: IconSize.base,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.theoryKeyTitle,
                      style: typo.verdict.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: Sp.xs),
                  Text(
                    block.body,
                    style: typo.body.copyWith(color: colors.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A table with a tinted header row. Each column gets the width its content
/// needs, not an equal share: never narrower than its longest word (so no
/// word is split in the middle, at any text size) and, when there is room,
/// wider for the columns with long texts. When even the narrowest columns do
/// not fit, the table keeps that width and scrolls sideways instead of
/// squeezing the text.
///
/// The sideways scroll shows a scrollbar so it is not invisible.
///
/// For a screen reader each body row reads as «Columna: valor» pairs.
class TheoryTable extends StatefulWidget {
  const TheoryTable({super.key, required this.table});

  final TableBlock table;

  /// When the table has to scroll, a column with long texts is at least this
  /// wide (at text scale 1; it grows with the text) so its sentences stay
  /// readable. A column of short texts is only as wide as its longest word.
  static const double minColumnWidth = 104;

  /// Widest a column asks for on its own (at text scale 1) before the
  /// remaining room is shared: past this its text wraps.
  static const double preferredColumnWidth = 160;

  /// The width of each column of [table] in a [maxWidth] dp wide space, and
  /// whether the table has to scroll sideways (the widths then add up to more
  /// than [maxWidth]).
  ///
  /// [measure] gives the width of a text on one line in the style of the
  /// cell. Exposed for the tests.
  @visibleForTesting
  static ({List<double> widths, bool scrolls}) columnWidths({
    required TableBlock table,
    required double maxWidth,
    required TextScaler textScaler,
    required double Function(String text, int column, bool header) measure,
  }) {
    const padding = 2 * Sp.m;
    final columns = table.headers.length;
    final hard = List<double>.filled(columns, 0);
    final natural = List<double>.filled(columns, 0);
    final separator = RegExp(r'[ \t\r\n]+');

    void take(String text, int column, {required bool header}) {
      var longestWord = 0.0;
      for (final word in text.split(separator)) {
        if (word.isEmpty) continue;
        longestWord = math.max(longestWord, measure(word, column, header));
      }
      hard[column] = math.max(hard[column], longestWord);
      natural[column] = math.max(
        natural[column],
        measure(text, column, header),
      );
    }

    for (var c = 0; c < columns; c++) {
      take(table.headers[c], c, header: true);
    }
    for (final row in table.rows) {
      for (var c = 0; c < columns && c < row.length; c++) {
        take(row[c], c, header: false);
      }
    }

    // A pixel to spare against rounding in the text layout.
    final min = [for (final w in hard) w.ceilToDouble() + padding + 1];
    final pref = [
      for (var c = 0; c < columns; c++)
        math.max(
          min[c],
          math.min(
            natural[c].ceilToDouble() + padding + 1,
            textScaler.scale(preferredColumnWidth),
          ),
        ),
    ];
    final sumMin = min.fold(0.0, (a, b) => a + b);
    final sumPref = pref.fold(0.0, (a, b) => a + b);

    if (sumMin > maxWidth) {
      final floor = textScaler.scale(minColumnWidth);
      return (
        widths: [
          for (var c = 0; c < columns; c++)
            math.max(min[c], math.min(pref[c], floor)),
        ],
        scrolls: true,
      );
    }
    final widths = sumPref <= maxWidth
        // Everything fits as it wants: share the spare room by weight.
        ? [for (final w in pref) w * maxWidth / sumPref]
        // Between the minimum and the preferred widths.
        : [
            for (var c = 0; c < columns; c++)
              min[c] +
                  (maxWidth - sumMin) * (pref[c] - min[c]) / (sumPref - sumMin),
          ];
    // The last one takes the rounding so the row is exactly [maxWidth] wide.
    widths[columns - 1] =
        maxWidth - widths.take(columns - 1).fold(0.0, (a, b) => a + b);
    return (widths: widths, scrolls: false);
  }

  @override
  State<TheoryTable> createState() => _TheoryTableState();
}

class _TheoryTableState extends State<TheoryTable> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final textScaler = MediaQuery.textScalerOf(context);
    final cell = typo.subtitle.copyWith(color: colors.textPrimary);
    final head = AptoTypography.weight(
      typo.subtitle,
      700,
    ).copyWith(color: colors.onPrimaryContainer);
    final first = AptoTypography.weight(cell, 600);
    TextStyle styleOf(int column, {required bool header}) =>
        header ? head : (column == 0 ? first : cell);

    final measured = <(String, TextStyle), double>{};
    double measure(String text, int column, bool header) {
      final style = styleOf(column, header: header);
      return measured.putIfAbsent((text, style), () {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });
    }

    Widget row(
      List<String> cells,
      List<double> widths, {
      required bool header,
    }) {
      final children = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, text) in cells.indexed)
            SizedBox(
              width: widths[i],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Sp.m,
                  vertical: Sp.m,
                ),
                child: Text(text, style: styleOf(i, header: header)),
              ),
            ),
        ],
      );
      if (header) {
        return ColoredBox(color: colors.primaryContainer, child: children);
      }
      return Semantics(
        container: true,
        label: [
          for (final (i, text) in cells.indexed)
            l10n.theoryTableCell(table.headers[i], text),
        ].join('. '),
        excludeSemantics: true,
        child: children,
      );
    }

    Widget body(List<double> widths) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(table.headers, widths, header: true),
        for (final (i, cells) in table.rows.indexed) ...[
          if (i > 0) const CardDivider(),
          row(cells, widths, header: false),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (table.caption != null) ...[
          Text(table.caption!, style: typo.caption),
          const SizedBox(height: Sp.s),
        ],
        Semantics(
          container: true,
          label: l10n.theoryTableSemantics(
            table.rows.length,
            table.headers.length,
          ),
          child: ClipRRect(
            borderRadius: Rad.chipRadius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.outline),
                borderRadius: Rad.chipRadius,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = TheoryTable.columnWidths(
                    table: table,
                    maxWidth: constraints.maxWidth,
                    textScaler: textScaler,
                    measure: measure,
                  );
                  if (!layout.scrolls) return body(layout.widths);
                  final total = layout.widths.fold(0.0, (a, b) => a + b);
                  return Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      // Room below the last row for the scrollbar.
                      padding: const EdgeInsets.only(bottom: Sp.m),
                      child: SizedBox(width: total, child: body(layout.widths)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
