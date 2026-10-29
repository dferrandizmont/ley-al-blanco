import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_date_format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/raised_card.dart';
import '../application/progress_transfer_providers.dart';
import '../data/progress_file_store.dart';
import '../domain/progress_snapshot.dart';

/// TUS DATOS (Ajustes): «Exportar progreso» saves the progress to a file the
/// user places where they want, «Importar progreso» reads one back after a
/// confirmation. There are no accounts: this is how progress moves to
/// another phone. Both go through the system file dialogs
/// ([progressFileStoreProvider]); nothing is sent anywhere.
///
/// Building and parsing the file runs on another isolate; a progress bar
/// along the top of the card shows it, and the rows do nothing meanwhile.
class DataTransferCard extends ConsumerStatefulWidget {
  const DataTransferCard({super.key});

  @override
  ConsumerState<DataTransferCard> createState() => _DataTransferCardState();
}

class _DataTransferCardState extends ConsumerState<DataTransferCard> {
  /// An export or an import is under way: the rows do nothing meanwhile.
  bool _busy = false;

  /// The file is being built, read or written (on another isolate for the
  /// big part): a progress bar shows it.
  bool _working = false;

  /// Runs [task] with the progress bar visible.
  Future<T> _whileWorking<T>(Future<T> Function() task) async {
    if (mounted) setState(() => _working = true);
    try {
      return await task();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _export() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final built = await _whileWorking(
        ref.read(progressTransferProvider).buildExport,
      );
      final saved = await ref
          .read(progressFileStoreProvider)
          .save(fileName: built.fileName, bytes: built.bytes);
      if (mounted && saved) _snack(l10n.settingsExportDone);
    } on ProgressExportTooLargeException {
      if (mounted) _snack(l10n.settingsExportTooLarge);
    } on Object catch (e) {
      debugPrint('progress export failed: ${e.runtimeType}');
      if (mounted) _snack(l10n.settingsExportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _runImport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    final l10n = context.l10n;
    final transfer = ref.read(progressTransferProvider);

    final PickedProgressFile picked;
    try {
      picked = await ref.read(progressFileStoreProvider).pick();
    } on Object catch (e) {
      debugPrint('progress file pick failed: ${e.runtimeType}');
      if (mounted) await _showError(l10n.settingsImportErrorFailed);
      return;
    }
    if (!mounted) return;

    final ProgressImportPlan plan;
    switch (picked) {
      case PickCancelled():
        return;
      case PickTooLarge():
        await _showError(l10n.settingsImportErrorTooLarge);
        return;
      case PickedBytes(:final bytes):
        try {
          plan = await _whileWorking(() => transfer.preview(bytes));
        } on ProgressImportException catch (e) {
          // The technical detail (field names, in English) is for whoever
          // debugs: the user only gets the localized message.
          debugPrint('progress import refused: $e');
          if (mounted) await _showError(_messageOf(e.error));
          return;
        } on Object catch (e) {
          debugPrint('progress import failed: ${e.runtimeType}');
          if (mounted) await _showError(l10n.settingsImportErrorFailed);
          return;
        }
    }
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmImportDialog(plan: plan),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _whileWorking(() => transfer.apply(plan));
    } on Object catch (e) {
      debugPrint('progress import write failed: ${e.runtimeType}');
      if (mounted) await _showError(l10n.settingsImportErrorFailed);
      return;
    }
    if (mounted) _snack(l10n.settingsImportDone);
  }

  String _messageOf(ProgressImportError error) {
    final l10n = context.l10n;
    return switch (error) {
      ProgressImportError.tooLarge => l10n.settingsImportErrorTooLarge,
      ProgressImportError.notJson => l10n.settingsImportErrorNotJson,
      ProgressImportError.wrongFormat => l10n.settingsImportErrorWrongFormat,
      ProgressImportError.newerVersion => l10n.settingsImportErrorNewerVersion,
      ProgressImportError.wrongEdition => l10n.settingsImportErrorWrongEdition,
      ProgressImportError.invalidDateTime => l10n.settingsImportErrorDateTime,
      ProgressImportError.tooDeep => l10n.settingsImportErrorTooDeep,
      ProgressImportError.invalid => l10n.settingsImportErrorInvalid,
    };
  }

  Future<void> _showError(String message) {
    final l10n = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsImportErrorTitle),
        content: Text(message),
        // The dialog scrolls: with very large text on a small screen the
        // message does not fit and the last line would be cut.
        scrollable: true,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.settingsImportErrorOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Stack(
      children: [
        Column(
          children: [
            _ActionRow(
              title: l10n.settingsExportTitle,
              subtitle: l10n.settingsExportSubtitle,
              icon: Icons.ios_share_rounded,
              onTap: _busy ? null : _export,
            ),
            const CardDivider(),
            _ActionRow(
              title: l10n.settingsImportTitle,
              subtitle: l10n.settingsImportSubtitle,
              icon: Icons.folder_open_rounded,
              onTap: _busy ? null : _import,
            ),
          ],
        ),
        if (_working)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Semantics(
              label: l10n.settingsTransferWorking,
              child: const LinearProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

/// A tappable row of the card: title, a short explanation and an icon.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Null while busy.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: l10n.semanticsTitleSubtitle(title, subtitle),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sp.touch + Sp.s),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Sp.l,
              vertical: Sp.m,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: typo.rowTitle),
                      const SizedBox(height: Sp.xxs),
                      Text(subtitle, style: typo.subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: Sp.m),
                Icon(
                  icon,
                  size: IconSize.base,
                  color: onTap == null ? colors.outline : colors.outlineStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The confirmation: replaces the current progress, and what the file brings.
class _ConfirmImportDialog extends StatelessWidget {
  const _ConfirmImportDialog({required this.plan});

  final ProgressImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typo = context.typo;
    final s = plan.snapshot;
    final lines = [
      l10n.settingsImportSummaryAnswersWrong(
        l10n.settingsImportSummaryAnswers(s.attempts.length),
        l10n.settingsImportSummaryWrong(s.wrongAttempts),
      ),
      l10n.settingsImportSummaryMocks(s.mocks.length),
      l10n.settingsImportSummaryReview(s.srs.length),
      l10n.settingsImportSummaryDate(
        const AppDateFormat().dayMonthYear(s.exportedAt),
      ),
    ];
    return AlertDialog(
      title: Text(l10n.settingsImportConfirmTitle),
      // The dialog scrolls: with very large text on a small screen the
      // summary does not fit and the last line would be cut.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsImportConfirmBody),
          const SizedBox(height: Sp.m),
          for (final line in lines) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.xs),
              child: Text(line, style: AptoTypography.tabular(typo.label)),
            ),
          ],
          if (plan.discardedTotal > 0) ...[
            const SizedBox(height: Sp.s),
            Text(
              l10n.settingsImportDiscarded(plan.discardedTotal),
              style: typo.subtitle,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.settingsImportReplace),
        ),
      ],
    );
  }
}
