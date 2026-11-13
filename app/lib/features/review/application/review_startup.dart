import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'review_providers.dart';

/// Counts civil days at startup and when returning to the foreground.
class ReviewStartup extends ConsumerStatefulWidget {
  const ReviewStartup({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReviewStartup> createState() => _ReviewStartupState();
}

class _ReviewStartupState extends ConsumerState<ReviewStartup> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _record);
    _record();
  }

  void _record() => unawaited(ref.read(reviewServiceProvider).recordOpen());

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
