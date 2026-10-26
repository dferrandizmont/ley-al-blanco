import 'package:flutter/material.dart';

import 'apto_colors.dart';

/// Text styles of the "Sereno" design (docs/design-sereno.md): Public Sans, one
/// variable file bundled with the app (`wght` axis, 400-700). Sizes are
/// logical pixels and scale with the user's text size: nothing clamps the text
/// scaler.
///
/// The weight is set twice, as `fontWeight` and as the `wght` variation, so it
/// renders the same everywhere. Never `copyWith(fontWeight: ...)` on one of
/// these styles: use [weight].
@immutable
class AptoTypography extends ThemeExtension<AptoTypography> {
  const AptoTypography({
    required this.display,
    required this.score,
    required this.title,
    required this.stem,
    required this.option,
    required this.optionStrong,
    required this.body,
    required this.label,
    required this.overline,
    required this.caption,
    required this.subtitle,
    required this.rowTitle,
    required this.verdict,
    required this.lead,
    required this.counter,
    required this.brand,
    required this.badge,
    required this.chip,
    required this.buttonCount,
  });

  static const String family = 'PublicSans';

  /// The big "17" of the result (48 / 700, tabular, tracking -2 %).
  final TextStyle display;

  /// Scores and counters, the ring of Inicio (34 / 700, tabular).
  final TextStyle score;

  /// Screen titles (26 / 700).
  final TextStyle title;

  /// Question stem (21 / 600, leading 1.38).
  final TextStyle stem;

  /// Answer options (17 / 400) and the right one (17 / 600).
  final TextStyle option;
  final TextStyle optionStrong;

  /// Explanations and running text (16 / 400, leading 1.5).
  final TextStyle body;

  /// Buttons and tile titles (17 / 700).
  final TextStyle label;

  /// Section labels (13 / 600, tracking 6 %). Written upper case by the
  /// `Overline` widget; this style only sets the look (secondary colour).
  final TextStyle overline;

  /// Footnotes, legal text (13 / 400, secondary colour).
  final TextStyle caption;

  /// Row subtitles (14 / 400, secondary colour).
  final TextStyle subtitle;

  /// Row titles in lists (16 / 600).
  final TextStyle rowTitle;

  /// Verdict lines, "Correcto" / "Incorrecto" (15 / 700). Colour at the use.
  final TextStyle verdict;

  /// Status lines (17 / 600).
  final TextStyle lead;

  /// "5 / 68" counters (15 / 600, tabular, secondary colour).
  final TextStyle counter;

  /// The app name in the header (19 / 700).
  final TextStyle brand;

  /// The APTO / NO APTO pill (22 / 700, tracking).
  final TextStyle badge;

  /// Filter chips, "Todos" / "Tema 3" (16 / 600). Colour set by the chip
  /// theme (selected or not).
  final TextStyle chip;

  /// The count after the label of a pill, "15 preguntas para hoy" (14 / 600,
  /// in [AptoColors.onAccent]: it sits on the orange pill).
  final TextStyle buttonCount;

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    int weight,
    Color color, {
    double? height,
    double letterSpacing = 0,
    bool tabularFigures = false,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: tabularFigures ? _tabular : null,
    leadingDistribution: TextLeadingDistribution.even,
  );

  factory AptoTypography.from(AptoColors c) => AptoTypography(
    display: _style(
      48,
      700,
      c.textPrimary,
      height: 1.0,
      letterSpacing: -0.96,
      tabularFigures: true,
    ),
    score: _style(34, 700, c.textPrimary, height: 1.1, tabularFigures: true),
    title: _style(26, 700, c.textPrimary, height: 1.22),
    stem: _style(21, 600, c.textPrimary, height: 1.38),
    option: _style(17, 400, c.textPrimary, height: 1.3),
    optionStrong: _style(17, 600, c.textPrimary, height: 1.3),
    body: _style(16, 400, c.textPrimary, height: 1.5),
    label: _style(17, 700, c.textPrimary, height: 1.25),
    overline: _style(
      13,
      600,
      c.textSecondary,
      height: 1.3,
      letterSpacing: 0.78,
    ),
    caption: _style(13, 400, c.textSecondary, height: 1.35),
    subtitle: _style(14, 400, c.textSecondary, height: 1.35),
    rowTitle: _style(16, 600, c.textPrimary, height: 1.3),
    verdict: _style(15, 700, c.textPrimary, height: 1.35),
    lead: _style(17, 600, c.textPrimary, height: 1.3),
    counter: _style(
      15,
      600,
      c.textSecondary,
      height: 1.2,
      tabularFigures: true,
    ),
    brand: _style(19, 700, c.textPrimary, height: 1.2),
    badge: _style(22, 700, c.textPrimary, height: 1.2, letterSpacing: 0.66),
    chip: _style(16, 600, c.textPrimary, height: 1.3),
    buttonCount: _style(14, 600, c.onAccent, height: 1.3),
  );

  /// Tabular figures on any style.
  static TextStyle tabular(TextStyle style) =>
      style.copyWith(fontFeatures: _tabular);

  /// [style] at [weight] (100..900 in steps of 100): sets the font weight and
  /// the `wght` axis together.
  static TextStyle weight(TextStyle style, int weight) => style.copyWith(
    fontWeight: FontWeight.values[(weight ~/ 100) - 1],
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );

  /// Flutter [TextTheme] mapping so stock Material widgets stay on-brand.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: display,
    displayMedium: display,
    displaySmall: score,
    headlineLarge: title,
    headlineMedium: title,
    headlineSmall: title,
    titleLarge: brand,
    titleMedium: rowTitle,
    titleSmall: label,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: caption,
    labelSmall: overline,
  );

  @override
  AptoTypography copyWith({
    TextStyle? display,
    TextStyle? score,
    TextStyle? title,
    TextStyle? stem,
    TextStyle? option,
    TextStyle? optionStrong,
    TextStyle? body,
    TextStyle? label,
    TextStyle? overline,
    TextStyle? caption,
    TextStyle? subtitle,
    TextStyle? rowTitle,
    TextStyle? verdict,
    TextStyle? lead,
    TextStyle? counter,
    TextStyle? brand,
    TextStyle? badge,
    TextStyle? chip,
    TextStyle? buttonCount,
  }) => AptoTypography(
    display: display ?? this.display,
    score: score ?? this.score,
    title: title ?? this.title,
    stem: stem ?? this.stem,
    option: option ?? this.option,
    optionStrong: optionStrong ?? this.optionStrong,
    body: body ?? this.body,
    label: label ?? this.label,
    overline: overline ?? this.overline,
    caption: caption ?? this.caption,
    subtitle: subtitle ?? this.subtitle,
    rowTitle: rowTitle ?? this.rowTitle,
    verdict: verdict ?? this.verdict,
    lead: lead ?? this.lead,
    counter: counter ?? this.counter,
    brand: brand ?? this.brand,
    badge: badge ?? this.badge,
    chip: chip ?? this.chip,
    buttonCount: buttonCount ?? this.buttonCount,
  );

  @override
  AptoTypography lerp(ThemeExtension<AptoTypography>? other, double t) {
    if (other is! AptoTypography) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AptoTypography(
      display: l(display, other.display),
      score: l(score, other.score),
      title: l(title, other.title),
      stem: l(stem, other.stem),
      option: l(option, other.option),
      optionStrong: l(optionStrong, other.optionStrong),
      body: l(body, other.body),
      label: l(label, other.label),
      overline: l(overline, other.overline),
      caption: l(caption, other.caption),
      subtitle: l(subtitle, other.subtitle),
      rowTitle: l(rowTitle, other.rowTitle),
      verdict: l(verdict, other.verdict),
      lead: l(lead, other.lead),
      counter: l(counter, other.counter),
      brand: l(brand, other.brand),
      badge: l(badge, other.badge),
      chip: l(chip, other.chip),
      buttonCount: l(buttonCount, other.buttonCount),
    );
  }
}
