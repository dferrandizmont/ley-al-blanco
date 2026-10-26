import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/l10n/tema_title.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../../content/application/content_providers.dart';
import '../application/mistakes_providers.dart';
import '../domain/mistakes.dart';
import 'mistake_sheet.dart';

/// Fallos: the questions currently failed, filterable by tema, with
/// "Repasar todos" to run a review session over what is listed.
class MistakesScreen extends ConsumerStatefulWidget {
  const MistakesScreen({super.key});

  @override
  ConsumerState<MistakesScreen> createState() => _MistakesScreenState();
}

class _MistakesScreenState extends ConsumerState<MistakesScreen> {
  /// null = every tema.
  int? _tema;

  /// `/fallos/repasar` for what is listed (the tema filter), starting at
  /// [from]'s question when given.
  String _reviewLocation([MistakeEntry? from]) {
    final query = {
      if (_tema != null) 'tema': '$_tema',
      if (from != null) 'desde': from.questionId,
    };
    return Uri(
      path: '/fallos/repasar',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = mistakesProvider(_tema);
    final async = ref.watch(provider);
    final entries = async.value;
    final stems = {
      for (final q in ref.watch(questionsProvider).value ?? const []) q.id: q,
    };

    final Widget list;
    if (async.hasError && entries == null) {
      list = ErrorState(
        title: l10n.loadErrorTitle,
        onRetry: () => ref.invalidate(provider),
      );
    } else if (entries == null) {
      list = const Center(child: CircularProgressIndicator());
    } else if (entries.isEmpty) {
      list = EmptyState(
        icon: Icons.task_alt_rounded,
        title: l10n.mistakesEmptyTitle,
        message: l10n.mistakesEmptyMessage,
      );
    } else {
      // Room under the floating "Repasar todos", so the card can scroll
      // clear of it instead of ending flat behind it.
      list = ScrollEdgeFade(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.s,
            Sp.page,
            Sp.floatingClearance,
          ),
          child: RaisedCard(
            child: Column(
              children: [
                for (final (i, entry) in entries.indexed) ...[
                  if (i > 0) const CardDivider(),
                  _MistakeRow(
                    tema: stems[entry.questionId]?.tema,
                    stem: stems[entry.questionId]?.stem ?? entry.questionId,
                    entry: entry,
                    // Opens the ficha; its "Practicar" button starts the
                    // review of what is listed from this question.
                    onTap: stems[entry.questionId] == null
                        ? () => context.push(_reviewLocation(entry))
                        : () => showMistakeSheet(
                            context,
                            question: stems[entry.questionId]!,
                            onPractice: () =>
                                context.push(_reviewLocation(entry)),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AptoAppBar(
        title: l10n.homeMistakesTitle,
        actions: [
          RoundIconButton(
            icon: Icons.search_rounded,
            tooltip: l10n.searchTooltip,
            onPressed: () => context.push('/buscar'),
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          child: Stack(
            children: [
              Column(
                children: [
                  _TemaFilter(
                    selected: _tema,
                    onSelected: (tema) => setState(() => _tema = tema),
                  ),
                  Expanded(child: list),
                ],
              ),
              Positioned(
                left: Sp.page,
                right: Sp.page,
                bottom: Sp.floatingMargin,
                child: PrimaryButton(
                  label: l10n.mistakesReviewAll,
                  floating: true,
                  onPressed: entries == null || entries.isEmpty
                      ? null
                      : () => context.push(_reviewLocation()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill chips "Todos" and "Tema 1".."Tema 7", scrolling sideways.
class _TemaFilter extends StatelessWidget {
  const _TemaFilter({required this.selected, required this.onSelected});

  final int? selected;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Look (stadium shape, shadow or border, label style) comes from the
    // theme's `chipTheme`; the padded tap target keeps the hit area >= 44 dp.
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => ChoiceChip(
      label: Text(label),
      selected: selected,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (_) => onTap(),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Sp.page, vertical: Sp.s),
      child: Row(
        children: [
          chip(
            label: l10n.mistakesFilterAll,
            selected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (var tema = 1; tema <= kTemaCount; tema++) ...[
            const SizedBox(width: Sp.s),
            chip(
              label: l10n.temaLabel(tema),
              selected: selected == tema,
              onTap: () => onSelected(tema),
            ),
          ],
        ],
      ),
    );
  }
}

class _MistakeRow extends StatelessWidget {
  const _MistakeRow({
    required this.tema,
    required this.stem,
    required this.entry,
    required this.onTap,
  });

  final int? tema;
  final String stem;
  final MistakeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final wrong = l10n.mistakesWrongCount(entry.wrongCount);
    return Semantics(
      button: true,
      label: [if (tema != null) l10n.temaLabel(tema!), stem, wrong].join('. '),
      hint: l10n.mistakesRowHint,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.incorrectContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: Sp.xxl,
                    child: Icon(
                      Icons.close_rounded,
                      size: IconSize.inline,
                      color: colors.incorrect,
                    ),
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tema != null)
                        Text(l10n.temaLabel(tema!), style: typo.subtitle),
                      Text(
                        stem,
                        style: typo.rowTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Sp.xs),
                      Text(wrong, style: AptoTypography.tabular(typo.subtitle)),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.s),
                Icon(
                  Icons.chevron_right_rounded,
                  size: IconSize.base,
                  color: colors.outlineStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
