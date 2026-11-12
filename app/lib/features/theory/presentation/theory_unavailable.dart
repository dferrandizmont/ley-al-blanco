import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../application/theory_providers.dart';

/// What the Teoría screens show when there is no theory to read: a calm error
/// with «Reintentar» when it failed to load (missing file, checksum that does
/// not match, invalid content), or the plain notice when this edition ships
/// none. The content is never shown unverified.
class TheoryUnavailable extends ConsumerWidget {
  const TheoryUnavailable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (theoryLoadFailed(ref.watch(theoryLoadProvider))) {
      return ErrorState(
        title: l10n.theoryLoadErrorTitle,
        message: l10n.theoryLoadErrorMessage,
        onRetry: () => ref.invalidate(theoryLoadProvider),
      );
    }
    return EmptyState(
      icon: Icons.menu_book_rounded,
      title: l10n.theoryUnavailableTitle,
      message: l10n.theoryUnavailableMessage,
    );
  }
}
