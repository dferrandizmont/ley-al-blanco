import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The decoration of a raised surface: [AptoColors.surfaceRaised] with the
/// card shadow in light and a 1 px `divider` border in dark.
BoxDecoration raisedDecoration(
  AptoColors colors, {
  BorderRadiusGeometry? borderRadius,
  BoxShape shape = BoxShape.rectangle,
  List<BoxShadow>? shadows,
}) => BoxDecoration(
  color: colors.surfaceRaised,
  shape: shape,
  borderRadius: shape == BoxShape.circle ? null : borderRadius,
  boxShadow: shadows ?? AptoShadows.card(colors),
  border: AptoShadows.raisedBorder(colors),
);

/// A raised card (radius 24 by default): the surface of the question, the
/// lists and the result. Tappable when [onTap] is given (the ink is clipped
/// to the corners).
class RaisedCard extends StatelessWidget {
  const RaisedCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = Rad.card,
    this.onTap,
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Corner radius: [Rad.card] (big cards) or [Rad.tile] (tiles).
  final double radius;
  final VoidCallback? onTap;

  /// Overrides the card shadow (light theme only).
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(radius);
    final content = Padding(padding: padding, child: child);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: raisedDecoration(
        colors,
        borderRadius: borderRadius,
        shadows: shadows,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// The 1 px separator between the rows of a [RaisedCard], or between the
/// question and its explanation.
class CardDivider extends StatelessWidget {
  const CardDivider({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: Sp.border,
    thickness: Sp.border,
    color: context.colors.divider,
  );
}
