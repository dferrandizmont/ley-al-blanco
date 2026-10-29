import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fitted_text.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/round_icon_button.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../application/theory_providers.dart';
import '../domain/theory.dart';
import 'theory_titles.dart';

/// Teoría: all seven summaries, practical exam, AEM and glossary.
/// Hidden from Inicio, and empty here, when the build has no theory.
class TheoryListScreen extends ConsumerWidget {
  const TheoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(theoryProvider);
    final bank = async.value;

    final Widget body;
    if (bank == null && async.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (bank == null) {
      body = EmptyState(
        icon: Icons.menu_book_rounded,
        title: l10n.theoryUnavailableTitle,
        message: l10n.theoryUnavailableMessage,
      );
    } else {
      body = ScrollEdgeFade(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Sp.page,
            Sp.s,
            Sp.page,
            Sp.section,
          ),
          child: _TheoryList(bank: bank),
        ),
      );
    }

    return Scaffold(
      appBar: AptoAppBar(
        title: l10n.theoryTitle,
        actions: [
          RoundIconButton(
            icon: Icons.search_rounded,
            tooltip: l10n.searchTooltip,
            onPressed: () => context.push('/buscar'),
          ),
        ],
      ),
      body: SafeArea(child: PageBody(child: body)),
    );
  }
}

class _TheoryList extends ConsumerWidget {
  const _TheoryList({required this.bank});

  final TheoryBank bank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typo = context.typo;
    final practica = bank.practica;
    final docs = bank.temaDocs;
    final aem = bank.aem;
    final glosario = bank.glosario;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
          child: Text(l10n.theoryIntro, style: typo.body),
        ),
        const SizedBox(height: Sp.l),
        if (practica != null) ...[
          _PracticaCard(
            title: l10n.theoryPracticaTitle,
            subtitle: l10n.theoryPracticaSubtitle,
            onTap: () => context.push('/teoria/${practica.id}'),
          ),
          const SizedBox(height: Sp.section),
        ],
        if (docs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Overline(l10n.theoryTemasTitle),
          ),
          const SizedBox(height: Sp.s),
          RaisedCard(
            child: Column(
              children: [
                for (final (i, doc) in docs.indexed) ...[
                  if (i > 0) const CardDivider(),
                  _DocRow(
                    tile: _NumberTile(doc.tema!),
                    semanticsPrefix: l10n.temaLabel(doc.tema!),
                    title: doc.displayTitle(l10n),
                    subtitle: l10n.theoryRead(doc.readingMinutes),
                    onTap: () => context.push('/teoria/${doc.id}'),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (aem != null || glosario != null) ...[
          const SizedBox(height: Sp.section),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
            child: Overline(l10n.theoryExtrasTitle),
          ),
          const SizedBox(height: Sp.s),
          RaisedCard(
            child: Column(
              children: [
                if (aem != null)
                  _DocRow(
                    tile: const _IconTile(Icons.family_restroom_rounded),
                    title: aem.title,
                    subtitle: l10n.theoryRead(aem.readingMinutes),
                    onTap: () => context.push('/teoria/${aem.id}'),
                  ),
                if (aem != null && glosario != null) const CardDivider(),
                if (glosario != null)
                  _DocRow(
                    tile: const _IconTile(Icons.sort_by_alpha_rounded),
                    title: glosario.title,
                    subtitle: l10n.theoryGlossarySubtitle(glosario.termCount),
                    onTap: () => context.push('/teoria/${glosario.id}'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The highlighted card of «La prueba práctica»: brand green.
class _PracticaCard extends StatelessWidget {
  const _PracticaCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    return Semantics(
      button: true,
      label: l10n.semanticsTitleSubtitle(title, subtitle),
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: Rad.cardRadius,
          boxShadow: AptoShadows.card(colors),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: Rad.cardRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Sp.cardPad),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.onPrimary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: Sp.x4 + Sp.s,
                      child: Icon(
                        Icons.gps_fixed_rounded,
                        size: IconSize.base,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: typo.label.copyWith(color: colors.onPrimary),
                        ),
                        const SizedBox(height: Sp.xs),
                        Text(
                          subtitle,
                          style: typo.subtitle.copyWith(
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  Icon(Icons.chevron_right_rounded, color: colors.onPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of a list card: a tile (the tema number or an icon), the title, a
/// subtitle with the reading time and a chevron.
class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.semanticsPrefix,
  });

  final Widget tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Read before the title («Tema 3»), when the tile carries a number.
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    return Semantics(
      button: true,
      label: [?semanticsPrefix, title, subtitle].join('. '),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                tile,
                const SizedBox(width: Sp.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedText(title, style: typo.rowTitle),
                      const SizedBox(height: Sp.xs),
                      Text(subtitle, style: typo.subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.s),
                Icon(Icons.chevron_right_rounded, color: colors.outlineStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Side of the tile at the start of a row.
const double _tileSize = Sp.x4 + Sp.xs;

/// The tema number on a tinted tile.
class _NumberTile extends StatelessWidget {
  const _NumberTile(this.tema);

  final int tema;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: Rad.chipRadius,
      ),
      child: SizedBox.square(
        dimension: _tileSize,
        child: Center(
          child: Text(
            '$tema',
            style: AptoTypography.tabular(
              context.typo.label.copyWith(color: colors.onPrimaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon on the same tinted tile (for the documents without a tema).
class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: Rad.chipRadius,
      ),
      child: SizedBox.square(
        dimension: _tileSize,
        child: Icon(
          icon,
          size: IconSize.base,
          color: colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
