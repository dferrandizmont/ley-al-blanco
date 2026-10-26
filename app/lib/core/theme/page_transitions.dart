import 'package:flutter/material.dart';

import 'spacing.dart';

/// Fade + 8 dp slide up (280 ms). Disabled when the user reduces motion.
class AptoPageTransitionsBuilder extends PageTransitionsBuilder {
  const AptoPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.curve,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 8 * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
