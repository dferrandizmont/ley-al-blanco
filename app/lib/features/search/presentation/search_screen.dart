import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/apto_app_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_body.dart';
import '../../../core/widgets/raised_card.dart';
import '../../../core/widgets/scroll_edge_fade.dart';
import '../../../core/widgets/search_field.dart';
import '../../content/domain/question.dart';
import '../../mistakes/application/mistakes_providers.dart';
import '../../mistakes/presentation/mistake_sheet.dart';
import '../application/search_providers.dart';
import '../domain/question_search.dart';

/// How many results are listed at most; the count above them is the total.
const int kMaxSearchResults = 50;

/// Buscar: a search field over the question bank (stems and options, without
/// accents or capitals, every word must match) and the questions found. A tap
/// opens the same ficha as Fallos (official answer, explanation, article,
/// notice, theory, practice).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(Question question) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // A question that was failed practises as in Fallos; any other one has
    // no review to start at, so its button opens its tema's practice. The
    // list is awaited: on a cold start it may not have loaded yet.
    var failed = false;
    try {
      final entries = await ref.read(mistakesProvider(null).future);
      failed = entries.any((entry) => entry.questionId == question.id);
    } catch (_) {
      // Without the list, the tema's practice is still a valid way in.
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    showMistakeSheet(
      context,
      question: question,
      practiceLabel: failed ? null : context.l10n.theoryPracticeThisTema,
      onPractice: () => router.push(
        failed
            ? '/fallos/repasar?desde=${question.id}'
            : '/tema/${question.tema}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _controller.text.trim();
    final searchable = isSearchable(query);

    final Widget results;
    if (!searchable) {
      results = EmptyState(
        icon: Icons.search_rounded,
        title: l10n.searchPromptTitle,
        message: l10n.searchPromptMessage,
      );
    } else {
      final provider = searchResultsProvider(query);
      final async = ref.watch(provider);
      final view = async.value;
      if (view == null && async.hasError) {
        results = ErrorState(
          title: l10n.loadErrorTitle,
          onRetry: () => ref.invalidate(provider),
        );
      } else if (view == null) {
        results = const Center(child: CircularProgressIndicator());
      } else if (view.isEmpty) {
        results = EmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.searchNoResultsTitle,
          message: l10n.searchNoResultsMessage,
        );
      } else {
        results = _Results(view: view, onOpen: _open);
      }
    }

    return Scaffold(
      appBar: AptoAppBar(title: l10n.searchTitle),
      body: SafeArea(
        child: PageBody(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Sp.page,
                  Sp.s,
                  Sp.page,
                  Sp.m,
                ),
                child: AptoSearchField(
                  controller: _controller,
                  autofocus: true,
                  hintText: l10n.searchHint,
                  clearTooltip: l10n.searchClear,
                  onChanged: (_) => setState(() {}),
                  onClear: () => setState(_controller.clear),
                ),
              ),
              Expanded(child: results),
            ],
          ),
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.view, required this.onOpen});

  final List<Question> view;
  final ValueChanged<Question> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typo = context.typo;
    final shown = view.take(kMaxSearchResults).toList();
    return ScrollEdgeFade(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(Sp.page, Sp.xs, Sp.page, Sp.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (view.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.searchResultsCount(view.length),
                    style: typo.subtitle,
                  ),
                ),
              ),
              const SizedBox(height: Sp.s),
            ],
            RaisedCard(
              child: Column(
                children: [
                  for (final (i, question) in shown.indexed) ...[
                    if (i > 0) const CardDivider(),
                    _ResultRow(
                      question: question,
                      onTap: () => onOpen(question),
                    ),
                  ],
                ],
              ),
            ),
            if (view.length > shown.length) ...[
              const SizedBox(height: Sp.m),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.xs),
                child: Text(
                  l10n.searchResultsTruncated(shown.length),
                  style: typo.subtitle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One question found: its tema over its stem (three lines at most) and a
/// chevron. The whole row is the button (at least 48 dp).
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.question, required this.onTap});

  final Question question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    final tema = l10n.temaLabel(question.tema);
    return Semantics(
      button: true,
      label: l10n.searchResultSemantics(tema, question.stem),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tema, style: typo.subtitle),
                      Text(
                        question.stem,
                        style: typo.rowTitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
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
