import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'empty_state.dart';

/// The one "could not load" state: an icon, a calm message and a "Reintentar"
/// button that runs [onRetry]. Never shows exception text to the user.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.onRetry,
    this.title,
    this.message,
    this.compact = false,
  });

  final VoidCallback onRetry;

  /// Defaults to the generic error message.
  final String? title;
  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: title ?? context.l10n.genericError,
      message: message,
      actionLabel: context.l10n.retry,
      onAction: onRetry,
      primaryAction: true,
      compact: compact,
    );
  }
}
