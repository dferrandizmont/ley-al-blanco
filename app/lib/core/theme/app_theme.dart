import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apto_colors.dart';
import 'apto_typography.dart';
import 'page_transitions.dart';
import 'shadows.dart';
import 'spacing.dart';

export 'theme_context.dart';

/// Builds the full Material 3 [ThemeData] from the "Sereno" design tokens
/// (docs/design-sereno.md): sand background, raised cards, pill buttons.
class AppTheme {
  const AppTheme._();

  /// Minimum touch target (48 dp).
  static const double minTouch = Sp.touch;

  /// Height of the primary call-to-action pill.
  static const double primaryButtonHeight = Sp.pillHeight;

  /// Height of the secondary pills and text buttons.
  static const double secondaryButtonHeight = 52;

  static ThemeData light() => _build(AptoColors.light);
  static ThemeData dark() => _build(AptoColors.dark);

  /// Transparent bars, icon brightness following the theme (edge-to-edge).
  static SystemUiOverlayStyle overlayStyle(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData _build(AptoColors c) {
    final type = AptoTypography.from(c);
    final brightness = c.brightness;
    const clear = Colors.transparent;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.primaryContainer,
      onSecondaryContainer: c.onPrimaryContainer,
      tertiary: c.accent,
      onTertiary: c.onAccent,
      error: c.incorrect,
      onError: c.isDark ? c.background : c.onPrimary,
      errorContainer: c.incorrectContainer,
      onErrorContainer: c.incorrectText,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.outlineStrong,
      outlineVariant: c.outline,
      shadow: c.textPrimary,
      scrim: c.scrim,
      inverseSurface: c.textPrimary,
      onInverseSurface: c.background,
      inversePrimary: c.primary,
      surfaceTint: clear,
      surfaceDim: c.background,
      surfaceBright: c.surfaceRaised,
      surfaceContainerLowest: c.surfaceRaised,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
    );

    const pill = StadiumBorder();
    final disabledFill = c.accent.withValues(alpha: 0.4);
    // Raised surfaces: a shadow in light (painted by the widgets, see
    // AptoShadows), a 1 px divider border in dark.
    final raisedSide = c.isDark
        ? BorderSide(color: c.divider)
        : BorderSide.none;

    WidgetStateProperty<Color?> overlayColor(Color base) =>
        WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return base.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return base.withValues(alpha: 0.08);
          }
          return null;
        });

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AptoTypography.family,
      textTheme: type.toTextTheme(),
      primaryTextTheme: type.toTextTheme(),
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      cardColor: c.surfaceRaised,
      dividerColor: c.divider,
      shadowColor: clear,
      splashColor: c.primary.withValues(alpha: 0.12),
      highlightColor: clear,
      hoverColor: c.primary.withValues(alpha: 0.08),
      focusColor: c.primary.withValues(alpha: 0.12),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [c, type],
      iconTheme: IconThemeData(color: c.textSecondary, size: IconSize.base),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AptoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AptoPageTransitionsBuilder(),
          TargetPlatform.linux: AptoPageTransitionsBuilder(),
          TargetPlatform.windows: AptoPageTransitionsBuilder(),
          // Keep the native edge-swipe back gesture on Apple platforms.
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: clear,
        shadowColor: clear,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: Sp.pillHeight + Sp.s,
        titleTextStyle: type.brand,
        iconTheme: IconThemeData(color: c.textPrimary, size: IconSize.base),
        actionsIconTheme: IconThemeData(
          color: c.textPrimary,
          size: IconSize.base,
        ),
        systemOverlayStyle: overlayStyle(brightness),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        surfaceTintColor: clear,
        shadowColor: clear,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Rad.cardRadius,
          side: raisedSide,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: Sp.border,
        space: Sp.border,
      ),
      // The sideways scrollbar of the theory tables: the default grey is
      // near-black on the dark card, so use the visible outline colour.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.outlineStrong),
      ),
      // Primary call to action: safety-orange pill, dark label.
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, primaryButtonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Sp.xxl, vertical: Sp.m),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(clear),
          surfaceTintColor: const WidgetStatePropertyAll(clear),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(type.label),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? disabledFill : c.accent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.onAccent.withValues(alpha: 0.6)
                : c.onAccent,
          ),
          iconColor: WidgetStatePropertyAll(c.onAccent),
          overlayColor: overlayColor(c.onAccent),
        ),
      ),
      // Secondary action: a raised pill (shadow painted by SecondaryButton).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(64, secondaryButtonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Sp.xl, vertical: Sp.m),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(clear),
          surfaceTintColor: const WidgetStatePropertyAll(clear),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(type.label),
          backgroundColor: WidgetStatePropertyAll(c.surfaceRaised),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.textSecondary.withValues(alpha: 0.5)
                : c.primary,
          ),
          iconColor: WidgetStatePropertyAll(c.primary),
          side: WidgetStatePropertyAll(
            BorderSide(color: c.optionBorder, width: Sp.border),
          ),
          overlayColor: overlayColor(c.primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, Sp.touch)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: Sp.l, vertical: Sp.s),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shape: const WidgetStatePropertyAll(pill),
          textStyle: WidgetStatePropertyAll(type.label),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? c.textSecondary.withValues(alpha: 0.5)
                : c.primary,
          ),
          iconColor: WidgetStatePropertyAll(c.primary),
          overlayColor: overlayColor(c.primary),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(Sp.touch, Sp.touch)),
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          iconColor: WidgetStatePropertyAll(c.textPrimary),
          overlayColor: overlayColor(c.textPrimary),
        ),
      ),
      // Filter chips (Fallos): raised stadium pills, the selected one in brand
      // green. The light-theme shadow belongs to the chip's own shape
      // (elevation + shadow colour), none in dark where the border stands in.
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceRaised,
        selectedColor: c.primary,
        disabledColor: c.surfaceRaised,
        surfaceTintColor: clear,
        shadowColor: c.isDark ? clear : AptoShadows.small(c).first.color,
        elevation: c.isDark ? 0 : 1,
        pressElevation: 0,
        showCheckmark: false,
        shape: StadiumBorder(side: raisedSide),
        side: raisedSide,
        padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.s),
        labelPadding: const EdgeInsets.symmetric(horizontal: Sp.xs),
        labelStyle: type.chip.copyWith(
          color: WidgetStateColor.resolveWith(
            (s) =>
                s.contains(WidgetState.selected) ? c.onPrimary : c.textPrimary,
          ),
        ),
        secondaryLabelStyle: type.chip.copyWith(color: c.onPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        modalBackgroundColor: c.surfaceRaised,
        surfaceTintColor: clear,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.outlineStrong,
        dragHandleSize: const Size(36, 4),
        clipBehavior: Clip.antiAlias,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: clear,
        shadowColor: clear,
        elevation: 0,
        barrierColor: c.scrim,
        titleTextStyle: type.brand,
        contentTextStyle: type.body,
        actionsPadding: const EdgeInsets.fromLTRB(Sp.l, 0, Sp.l, Sp.l),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.sheet),
          side: raisedSide,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: type.body.copyWith(color: c.background),
        actionTextColor: c.accent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(Sp.l),
        shape: RoundedRectangleBorder(borderRadius: Rad.optionRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? c.onPrimary : c.outlineStrong,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceRaised,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.outlineStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        circularTrackColor: clear,
        linearTrackColor: c.ringTrack,
        linearMinHeight: 8,
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
