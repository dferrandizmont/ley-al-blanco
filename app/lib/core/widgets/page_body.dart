import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centres page content and caps its width (~640 dp) so cards do not stretch
/// edge to edge on tablets and landscape.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = Sp.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
