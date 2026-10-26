import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../srs/application/srs_providers.dart';
import '../application/progress_providers.dart';

/// Keeps the providers behind Inicio (pass probability, tema summaries, daily
/// queue) listened to from the root of the app, so they are recomputed as the
/// answers come in.
///
/// Why: Riverpod pauses the subscriptions of a screen that another route
/// covers. When Inicio is uncovered again it would find a chain of dirty
/// providers and refresh them **inside its build**, which Riverpod reports as
/// "setState() called during build". With a listener here they are already
/// fresh (about 10 ms of Monte Carlo per answer) and Inicio shows the new
/// numbers the moment it returns.
class ProgressWarmup extends ConsumerWidget {
  const ProgressWarmup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref
      ..listen(passProbabilityProvider, (previous, next) {})
      ..listen(temaSummaryProvider, (previous, next) {})
      ..listen(dailyQueueProvider, (previous, next) {});
    return child;
  }
}
