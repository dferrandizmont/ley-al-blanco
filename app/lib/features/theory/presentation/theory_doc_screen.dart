import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/article_chip.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/overline.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../../../core/widgets/search_field.dart';
import '../application/theory_providers.dart';
import '../domain/theory.dart';
import 'theory_blocks.dart';
import 'theory_titles.dart';

/// The reader of one summary (`t1`..`t7`), of «La prueba práctica», of the AEM
/// or of the glossary: label, title and summary, then the sections as foldable
/// cards. A tema summary ends with a floating «Practicar este tema»; the
/// glossary has a search field above its sections.
class TheoryDocScreen extends ConsumerWidget {
  const TheoryDocScreen({super.key, required this.docId});

  /// `t1`..`t7`, `practica`, `aem` or `glosario`.
  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(theoryProvider);
    final doc = async.value?.byId(docId);

    final Widget body;
    if (doc != null) {
      body = _Reader(key: ValueKey(doc.id), doc: doc);
    } else if (async.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = EmptyState(
        icon: Icons.menu_book_rounded,
        title: l10n.theoryUnavailableTitle,
        message: l10n.theoryUnavailableMessage,
      );
    }
    return Scaffold(
      appBar: AptoAppBar(title: l10n.theoryTitle),
      body: SafeArea(child: PageBody(child: body)),
    );
  }
}

class _Reader extends StatefulWidget {
  const _Reader({super.key, required this.doc});

  final TheoryDoc doc;

  @override
  State<_Reader> createState() => _ReaderState();
}

class _ReaderState extends State<_Reader> {
  final TextEditingController _search = TextEditingController();

  bool get _isGlossary => widget.doc.id == kGlosarioDocId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _overline(AppLocalizations l10n) {
    final tema = widget.doc.tema;
    if (tema != null) return l10n.theoryTemaOverline(tema);
    return switch (widget.doc.id) {
      kAemDocId => l10n.theoryAemOverline,
      kGlosarioDocId => l10n.theoryGlosarioOverline,
      _ => l10n.theoryPracticaOverline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final doc = widget.doc;
    final tema = doc.tema;
    final query = _search.text.trim();
    final searching = _isGlossary && query.isNotEmpty;
    final shown = searching ? doc.filterTerms(query) : doc;
    final sectionKeyPrefix = searching ? 'q' : 's';
    return Stack(
      children: [
        ScrollEdgeFade(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              Sp.page,
              Sp.s,
              Sp.page,
              tema == null ? Sp.section : Sp.floatingClearance,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Overline(_overline(l10n), header: false),
                      const SizedBox(height: Sp.s),
                      Semantics(
                        header: true,
                        child: Text(doc.displayTitle(l10n), style: typo.title),
                      ),
                      const SizedBox(height: Sp.m),
                      Text(doc.summary, style: typo.body),
                    ],
                  ),
                ),
                if (_isGlossary) ...[
                  const SizedBox(height: Sp.xl),
                  AptoSearchField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    onClear: () => setState(_search.clear),
                    hintText: l10n.theoryGlossarySearchHint,
                    clearTooltip: l10n.theoryGlossarySearchClear,
                  ),
                  if (searching) ...[
                    const SizedBox(height: Sp.m),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.theoryGlossaryResults(shown?.termCount ?? 0),
                          style: typo.subtitle,
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: Sp.section),
                if (shown == null)
                  EmptyState(
                    compact: true,
                    icon: Icons.search_off_rounded,
                    title: l10n.theoryGlossaryNoResultsTitle,
                    message: l10n.theoryGlossaryNoResultsMessage,
                  )
                else
                  for (final (i, section) in shown.sections.indexed) ...[
                    if (i > 0) const SizedBox(height: Sp.card),
                    _SectionCard(
                      // A search unfolds every section; clearing it goes back
                      // to the folding the document says.
                      key: ValueKey('$sectionKeyPrefix-${doc.id}-$query-$i'),
                      section: section,
                    ),
                  ],
              ],
            ),
          ),
        ),
        if (tema != null)
          Positioned(
            left: Sp.page,
            right: Sp.page,
            bottom: Sp.floatingMargin,
            child: PrimaryButton(
              label: l10n.theoryPracticeThisTema,
              floating: true,
              onPressed: () => context.push('/tema/$tema'),
            ),
          ),
      ],
    );
  }
}

/// A foldable card: the title row toggles the blocks and the article chips.
/// Starts folded when the document says `collapsed`.
class _SectionCard extends StatefulWidget {
  const _SectionCard({super.key, required this.section});

  final TheorySection section;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  late bool _expanded = !widget.section.collapsed;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final section = widget.section;
    final articles = section.articlesNotInTerms;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        Sp.cardPad,
        Sp.l,
        Sp.cardPad,
        Sp.cardPad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, block) in section.blocks.indexed) ...[
            if (i > 0) const SizedBox(height: Sp.l),
            TheoryBlockView(block: block),
          ],
          if (articles.isNotEmpty) ...[
            const SizedBox(height: Sp.l),
            Wrap(
              spacing: Sp.s,
              runSpacing: Sp.s,
              children: [
                for (final article in articles) ArticleChip(article: article),
              ],
            ),
          ],
        ],
      ),
    );

    return RaisedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            button: true,
            expanded: _expanded,
            label: section.title,
            hint: _expanded
                ? l10n.theorySectionCollapseHint
                : l10n.theorySectionExpandHint,
            onTap: _toggle,
            excludeSemantics: true,
            child: InkWell(
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Sp.pillHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.cardPad,
                    vertical: Sp.m,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(section.title, style: typo.label)),
                      const SizedBox(width: Sp.s),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: colors.outlineStrong,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.state),
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [const CardDivider(), content],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
