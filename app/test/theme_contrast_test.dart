import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show HSVColor;

import 'package:apto_armas/core/theme/apto_colors.dart';
import 'package:apto_armas/core/widgets/app_mark_painter.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x relative luminance of an opaque colour.
double luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio, 1..21.
double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('contrast helper matches known WCAG values', () {
    expect(
      contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.001),
    );
    expect(
      contrast(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
      closeTo(1, 0.001),
    );
    // #767676 on white is the classic 4.54:1 AA threshold example.
    expect(
      contrast(const Color(0xFF767676), const Color(0xFFFFFFFF)),
      closeTo(4.54, 0.01),
    );
  });

  final themes = {'light': AptoColors.light, 'dark': AptoColors.dark};

  for (final entry in themes.entries) {
    final name = entry.key;
    final c = entry.value;

    group('$name theme text contrast >= 4.5:1', () {
      final pairs = <String, (Color, Color)>{
        // Body text on every surface.
        'textPrimary / background': (c.textPrimary, c.background),
        'textPrimary / surface': (c.textPrimary, c.surface),
        'textPrimary / surfaceRaised': (c.textPrimary, c.surfaceRaised),
        'textPrimary / primaryContainer': (c.textPrimary, c.primaryContainer),
        'textPrimary / correctContainer': (c.textPrimary, c.correctContainer),
        'textPrimary / incorrectContainer': (
          c.textPrimary,
          c.incorrectContainer,
        ),
        'textSecondary / background': (c.textSecondary, c.background),
        'textSecondary / surface': (c.textSecondary, c.surface),
        'textSecondary / surfaceRaised': (c.textSecondary, c.surfaceRaised),
        'textSecondary / primaryContainer': (
          c.textSecondary,
          c.primaryContainer,
        ),
        // Labels on filled controls.
        'onPrimary / primary': (c.onPrimary, c.primary),
        'onPrimaryContainer / primaryContainer': (
          c.onPrimaryContainer,
          c.primaryContainer,
        ),
        'onAccent / accent': (c.onAccent, c.accent),
        // Brand-coloured text: links, tema numbers, text buttons.
        'primary / background': (c.primary, c.background),
        'primary / surfaceRaised': (c.primary, c.surfaceRaised),
        'primary / primaryContainer': (c.primary, c.primaryContainer),
        // Verdicts and the mistakes badge.
        'correctText / correctContainer': (c.correctText, c.correctContainer),
        'correctText / surfaceRaised': (c.correctText, c.surfaceRaised),
        'correctText / background': (c.correctText, c.background),
        'incorrectText / incorrectContainer': (
          c.incorrectText,
          c.incorrectContainer,
        ),
        'incorrectText / surfaceRaised': (c.incorrectText, c.surfaceRaised),
        'incorrectText / background': (c.incorrectText, c.background),
        // The legal-reform notice callout (text, title and icon on amber).
        'onNoticeContainer / noticeContainer': (
          c.onNoticeContainer,
          c.noticeContainer,
        ),
      };
      for (final p in pairs.entries) {
        test(p.key, () {
          final ratio = contrast(p.value.$1, p.value.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name ${p.key} = ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    group('$name theme icon and border contrast >= 3:1', () {
      final pairs = <String, (Color, Color)>{
        // Check / cross icons on their containers and on cards.
        'correct / correctContainer': (c.correct, c.correctContainer),
        'incorrect / incorrectContainer': (c.incorrect, c.incorrectContainer),
        'correct / surfaceRaised': (c.correct, c.surfaceRaised),
        'incorrect / surfaceRaised': (c.incorrect, c.surfaceRaised),
        // The check / cross / letter drawn inside the filled option circle.
        'onPrimary / correct': (c.onPrimary, c.correct),
        'onPrimary / incorrect': (c.onPrimary, c.incorrect),
        // Resting border of an option card and of the secondary pill.
        'optionBorder / surfaceRaised': (c.optionBorder, c.surfaceRaised),
        // The orange shield on the brand tile (AppMark).
        'accent / brandTile': (c.accent, c.brandTile),
        // The sand shield on the tile, and the check (tile colour) on it.
        'sand shield / brandTile': (AppMarkPalette.shieldSand, c.brandTile),
        // Control boundaries and chevrons.
        'outlineStrong / background': (c.outlineStrong, c.background),
        'outlineStrong / surfaceRaised': (c.outlineStrong, c.surfaceRaised),
        // The unselected radio of the theme list sits on the ring track; the
        // scrollbar thumb on the card and on the surface.
        'outlineStrong / ringTrack': (c.outlineStrong, c.ringTrack),
        'outlineStrong / surface': (c.outlineStrong, c.surface),
        // Rings, bars and the selected-option border.
        'primary / surfaceRaised': (c.primary, c.surfaceRaised),
        'primary / background': (c.primary, c.background),
        'primary / ringTrack': (c.primary, c.ringTrack),
        'incorrect / ringTrack': (c.incorrect, c.ringTrack),
        'textPrimary / ringTrack (pass-mark tick)': (
          c.textPrimary,
          c.ringTrack,
        ),
        // Icons on the tinted chip and tile circles.
        'onPrimaryContainer / primaryContainer': (
          c.onPrimaryContainer,
          c.primaryContainer,
        ),
        'incorrectText / incorrectContainer': (
          c.incorrectText,
          c.incorrectContainer,
        ),
        // The info icon of the notice callout.
        'onNoticeContainer / noticeContainer': (
          c.onNoticeContainer,
          c.noticeContainer,
        ),
      };
      for (final p in pairs.entries) {
        test(p.key, () {
          final ratio = contrast(p.value.$1, p.value.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: '$name ${p.key} = ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });
  }

  test(
    'the option border sits between the hairline and the strong outline',
    () {
      for (final c in themes.values) {
        final raised = c.surfaceRaised;
        expect(contrast(c.optionBorder, raised), greaterThanOrEqualTo(3.0));
        // Above the decorative hairline, not heavier than the letter circle.
        expect(
          contrast(c.optionBorder, raised),
          greaterThan(contrast(c.outline, raised)),
        );
        expect(
          contrast(c.optionBorder, raised),
          lessThanOrEqualTo(contrast(c.outlineStrong, raised)),
        );
      }
    },
  );

  test('the brand tile keeps the spec orange shield and dark green', () {
    // Spec colours are untouched: the shield is the theme's accent and the
    // dark tile is the brand green #2F5D50.
    expect(AptoColors.light.accent, const Color(0xFFF27A1A));
    expect(AptoColors.dark.brandTile, const Color(0xFF2F5D50));
    // The light tile is a hair darker than the primary so the shield passes
    // 3:1 (the primary itself gives 2.7:1).
    expect(
      contrast(AptoColors.light.accent, AptoColors.light.primary),
      lessThan(3.0),
    );
  });

  test('the app icon palette: shield and check read, arc is decorative', () {
    const p = AppMarkPalette.icon;
    // Spec colours of the icon (docs/design-sereno.md).
    expect(p.background, const Color(0xFF2F5D50));
    expect(p.arc, const Color(0xFFF27A1A));
    expect(p.shield, const Color(0xFFEFE9DD));
    expect(contrast(p.shield, p.background), greaterThanOrEqualTo(3.0));
    expect(contrast(p.check, p.shield), greaterThanOrEqualTo(3.0));
    // The orange arc on #2F5D50 is 2.70:1 (below 3:1): fine for an app icon
    // (decorative, large, never the only carrier of the meaning), but it is
    // why the in-app tile token stays a hair darker (#2A5448, 3.08:1) and is
    // not #2F5D50 in light.
    expect(contrast(p.arc, p.background), closeTo(2.70, 0.02));
    expect(contrast(p.arc, p.background), lessThan(3.0));
    // The track is decorative.
    expect(contrast(p.track, p.background), lessThan(1.5));
  });

  test('the APTO ring colour reads on the card it sits on', () {
    // `correct` against the empty track is 2.7:1 in light (the doc's values);
    // the arc is bounded by the card (>= 3:1) and the verdict never relies on
    // the ring alone (number, pill with an icon, text).
    expect(
      contrast(AptoColors.light.correct, AptoColors.light.surfaceRaised),
      greaterThanOrEqualTo(3.0),
    );
  });

  test('white on the safety orange would fail AA, hence the dark onAccent', () {
    final white = contrast(const Color(0xFFFFFFFF), AptoColors.light.accent);
    expect(white, lessThan(4.5));
    expect(
      contrast(AptoColors.light.onAccent, AptoColors.light.accent),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('the notice is amber, not the red of an error', () {
    for (final c in themes.values) {
      // A notice must not read as a wrong answer: its fill is not the red
      // container, and its hue is warm yellow-orange rather than red.
      expect(c.noticeContainer, isNot(c.incorrectContainer));
      final hue = HSVColor.fromColor(c.noticeContainer).hue;
      expect(hue, inInclusiveRange(30, 55), reason: 'amber hue, was $hue');
      final incorrectHue = HSVColor.fromColor(c.incorrectContainer).hue;
      expect(
        (hue - incorrectHue).abs(),
        greaterThan(20),
        reason: 'clearly apart from the incorrect container',
      );
    }
  });

  test('correct / incorrect are not used as small text colours', () {
    // The text variants are darker (light) / lighter (dark) than the icons.
    for (final c in themes.values) {
      expect(
        contrast(c.correctText, c.surfaceRaised),
        greaterThan(contrast(c.correct, c.surfaceRaised)),
      );
      expect(
        contrast(c.incorrectText, c.surfaceRaised),
        greaterThan(contrast(c.incorrect, c.surfaceRaised)),
      );
    }
  });
}
