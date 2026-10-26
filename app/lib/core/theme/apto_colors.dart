import 'package:flutter/material.dart';

/// Colour tokens of the "Sereno" design (docs/design-sereno.md). The single
/// place where hex values live; widgets read them through `context.colors`.
///
/// Contrast (checked by `test/theme_contrast_test.dart`): text tokens against
/// their surfaces >= 4.5:1; icons and control borders >= 3:1. [correct] /
/// [incorrect] are for icons and fills, never small text (that is
/// [correctText] / [incorrectText]); they always travel with a check / cross
/// icon, never colour alone.
@immutable
class AptoColors extends ThemeExtension<AptoColors> {
  const AptoColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.divider,
    required this.outline,
    required this.outlineStrong,
    required this.optionBorder,
    required this.primary,
    required this.onPrimary,
    required this.brandTile,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.ringTrack,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.onAccent,
    required this.correct,
    required this.correctContainer,
    required this.correctText,
    required this.incorrect,
    required this.incorrectContainer,
    required this.incorrectText,
    required this.noticeContainer,
    required this.onNoticeContainer,
    required this.scrim,
  });

  final Brightness brightness;

  /// Screen background (sand / dark green-black).
  final Color background;

  /// Bars, sheets and grouped areas.
  final Color surface;

  /// Cards (question card, lists, tiles) and the small round buttons.
  final Color surfaceRaised;

  /// Separators inside cards and the 1 px border of raised surfaces in the
  /// dark theme (where there are no shadows).
  final Color divider;

  /// Decorative hairline (not a control boundary: see [optionBorder]).
  final Color outline;

  /// Control boundaries (the letter circle of an option, chevrons): >= 3:1
  /// against [background] and [surfaceRaised].
  final Color outlineStrong;

  /// Resting border of an option card and of the secondary pill: a muted tone
  /// between [outline] and [outlineStrong] that still reaches >= 3:1 against
  /// [surfaceRaised] (WCAG 1.4.11, boundary of a control).
  final Color optionBorder;

  /// Brand green: marks, rings, bars, links. Text on it: [onPrimary].
  final Color primary;
  final Color onPrimary;

  /// Fill of the [AppMark] tile (the arc on it is [accent], >= 3:1, and the
  /// shield is sand, >= 6:1). Dark green in both themes: in dark it is not the
  /// light [primary], which would leave the orange arc at 1.7:1.
  final Color brandTile;

  /// Tinted fill: article chip, selected option (mock), tick backgrounds.
  /// Text on it: [onPrimaryContainer].
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Empty part of rings and bars.
  final Color ringTrack;

  final Color textPrimary;
  final Color textSecondary;

  /// Safety orange: calls to action. Never used as text colour on light
  /// surfaces (2.3:1); the label on it is [onAccent], dark, because white on
  /// this orange fails WCAG AA.
  final Color accent;
  final Color onAccent;

  /// Right answer. Pair with a check icon.
  final Color correct;
  final Color correctContainer;

  /// "APTO" and the correct verdict: small text on cards or
  /// [correctContainer].
  final Color correctText;

  /// Wrong answer. Pair with a cross icon.
  final Color incorrect;
  final Color incorrectContainer;

  /// "NO APTO", the incorrect verdict and the mistakes badge: small text on
  /// cards or [incorrectContainer].
  final Color incorrectText;

  /// Legal-reform notice callout ("Aviso: cambio en la norma"): amber, never
  /// the red of a wrong answer, because a notice is not an error. Text and
  /// icon on it: [onNoticeContainer] (>= 4.5:1). It also travels with an icon
  /// and a title, never colour alone.
  final Color noticeContainer;
  final Color onNoticeContainer;

  /// Modal barrier.
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  static const AptoColors light = AptoColors(
    brightness: Brightness.light,
    background: Color(0xFFEFE9DD),
    surface: Color(0xFFF7F3EA),
    surfaceRaised: Color(0xFFFFFDF8),
    divider: Color(0xFFF1ECE2),
    outline: Color(0xFFD3CAB8),
    outlineStrong: Color(0xFF7A7160),
    optionBorder: Color(0xFF968D79),
    primary: Color(0xFF2F5D50),
    onPrimary: Color(0xFFFFFFFF),
    brandTile: Color(0xFF2A5448),
    primaryContainer: Color(0xFFE5EEEA),
    onPrimaryContainer: Color(0xFF1F3F36),
    ringTrack: Color(0xFFECE5D7),
    textPrimary: Color(0xFF1D2420),
    textSecondary: Color(0xFF4F5A54),
    accent: Color(0xFFF27A1A),
    onAccent: Color(0xFF1F1A14),
    correct: Color(0xFF2E9E5B),
    correctContainer: Color(0xFFEAF6EE),
    correctText: Color(0xFF1E6B3F),
    incorrect: Color(0xFFD64545),
    incorrectContainer: Color(0xFFFAE3E3),
    incorrectText: Color(0xFFA62F2F),
    noticeContainer: Color(0xFFFBEBC8),
    onNoticeContainer: Color(0xFF5C3A00),
    scrim: Color(0x66000000),
  );

  static const AptoColors dark = AptoColors(
    brightness: Brightness.dark,
    background: Color(0xFF141A17),
    surface: Color(0xFF1B2320),
    surfaceRaised: Color(0xFF1F2824),
    divider: Color(0xFF2A3530),
    outline: Color(0xFF3A4640),
    outlineStrong: Color(0xFF74847B),
    optionBorder: Color(0xFF66756D),
    primary: Color(0xFF8CC5B2),
    onPrimary: Color(0xFF0E2A22),
    brandTile: Color(0xFF2F5D50),
    primaryContainer: Color(0xFF23362F),
    onPrimaryContainer: Color(0xFFCFE5DC),
    ringTrack: Color(0xFF2C3833),
    textPrimary: Color(0xFFE8EDE9),
    textSecondary: Color(0xFFA9B5AE),
    accent: Color(0xFFFF8F3A),
    onAccent: Color(0xFF1F1A14),
    correct: Color(0xFF4CC37E),
    correctContainer: Color(0xFF1E3A2A),
    correctText: Color(0xFF7FD6A0),
    incorrect: Color(0xFFEF6B6B),
    incorrectContainer: Color(0xFF3E2222),
    incorrectText: Color(0xFFF4A3A3),
    noticeContainer: Color(0xFF3A2E14),
    onNoticeContainer: Color(0xFFF2D9A0),
    scrim: Color(0x99000000),
  );

  @override
  AptoColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? divider,
    Color? outline,
    Color? outlineStrong,
    Color? optionBorder,
    Color? primary,
    Color? onPrimary,
    Color? brandTile,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? ringTrack,
    Color? textPrimary,
    Color? textSecondary,
    Color? accent,
    Color? onAccent,
    Color? correct,
    Color? correctContainer,
    Color? correctText,
    Color? incorrect,
    Color? incorrectContainer,
    Color? incorrectText,
    Color? noticeContainer,
    Color? onNoticeContainer,
    Color? scrim,
  }) => AptoColors(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    divider: divider ?? this.divider,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    optionBorder: optionBorder ?? this.optionBorder,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    brandTile: brandTile ?? this.brandTile,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    ringTrack: ringTrack ?? this.ringTrack,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    correct: correct ?? this.correct,
    correctContainer: correctContainer ?? this.correctContainer,
    correctText: correctText ?? this.correctText,
    incorrect: incorrect ?? this.incorrect,
    incorrectContainer: incorrectContainer ?? this.incorrectContainer,
    incorrectText: incorrectText ?? this.incorrectText,
    noticeContainer: noticeContainer ?? this.noticeContainer,
    onNoticeContainer: onNoticeContainer ?? this.onNoticeContainer,
    scrim: scrim ?? this.scrim,
  );

  @override
  AptoColors lerp(ThemeExtension<AptoColors>? other, double t) {
    if (other is! AptoColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AptoColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      divider: l(divider, other.divider),
      outline: l(outline, other.outline),
      outlineStrong: l(outlineStrong, other.outlineStrong),
      optionBorder: l(optionBorder, other.optionBorder),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      brandTile: l(brandTile, other.brandTile),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      ringTrack: l(ringTrack, other.ringTrack),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      correct: l(correct, other.correct),
      correctContainer: l(correctContainer, other.correctContainer),
      correctText: l(correctText, other.correctText),
      incorrect: l(incorrect, other.incorrect),
      incorrectContainer: l(incorrectContainer, other.incorrectContainer),
      incorrectText: l(incorrectText, other.incorrectText),
      noticeContainer: l(noticeContainer, other.noticeContainer),
      onNoticeContainer: l(onNoticeContainer, other.onNoticeContainer),
      scrim: l(scrim, other.scrim),
    );
  }
}
