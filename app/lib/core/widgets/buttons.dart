import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one in-button / inline progress spinner (18 dp, 2.4 stroke). Takes
/// the surrounding icon colour unless [color] is given.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key, this.color, this.size = IconSize.inline});

  /// Stroke of the spinner.
  static const double stroke = 2.4;

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: stroke,
      color: color ?? IconTheme.of(context).color,
    ),
  );
}

/// Filled safety-orange pill (dark label), 56 dp tall, with an optional icon
/// and a loading state. At most one per view.
///
/// [floating] adds the orange glow of a button that hovers over scrolling
/// content (the "Siguiente" of the practice screen). [content] replaces the
/// text label with a custom child (then [semanticsLabel] is what is spoken).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.floating = false,
    this.content,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool floating;
  final Widget? content;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final handler = loading ? null : onPressed;
    final Widget child = content == null
        ? Text(label)
        : Semantics(
            label: semanticsLabel ?? label,
            excludeSemantics: true,
            child: content,
          );
    final Widget button = (icon == null && !loading)
        ? FilledButton(onPressed: handler, child: child)
        : FilledButton.icon(
            onPressed: handler,
            icon: loading
                ? ButtonSpinner(color: colors.onAccent)
                : Icon(icon, size: IconSize.button),
            label: child,
          );
    final Widget shaped = floating
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: Rad.pillRadius,
              boxShadow: AptoShadows.floating(colors),
            ),
            child: button,
          )
        : button;
    return expand ? SizedBox(width: double.infinity, child: shaped) : shaped;
  }
}

/// Borderless text button (brand-green label) with an optional icon at the
/// shared in-button size ([IconSize.button]), so a row mixing it with
/// [SecondaryButton]s keeps one icon size.
class TextActionButton extends StatelessWidget {
  const TextActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => icon == null
      ? TextButton(onPressed: onPressed, child: Text(label))
      : TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: IconSize.button),
          label: Text(label),
        );
}

/// Raised pill on the sand background (secondary action): a surface with the
/// small shadow in light, a divider border in dark.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Puts [icon] after the label (forward actions such as "Siguiente").
  final bool trailingIcon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: IconSize.button),
            label: Text(label),
            iconAlignment: trailingIcon
                ? IconAlignment.end
                : IconAlignment.start,
          );
    final shaped = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: Rad.pillRadius,
        boxShadow: AptoShadows.small(context.colors),
      ),
      child: button,
    );
    return expand ? SizedBox(width: double.infinity, child: shaped) : shaped;
  }
}
