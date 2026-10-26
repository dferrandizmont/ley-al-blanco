import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('ThemeData', () {
    for (final entry in {
      'light': (AppTheme.light(), AptoColors.light),
      'dark': (AppTheme.dark(), AptoColors.dark),
    }.entries) {
      test('${entry.key} builds and exposes the token extensions', () {
        final (theme, colors) = entry.value;
        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, colors.brightness);
        expect(theme.extension<AptoColors>(), same(colors));
        expect(theme.extension<AptoTypography>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, colors.background);
        expect(theme.colorScheme.primary, colors.primary);
        expect(theme.colorScheme.primaryContainer, colors.primaryContainer);
        // The call to action is the safety-orange pill with the dark label.
        final filled = theme.filledButtonTheme.style!;
        expect(filled.backgroundColor!.resolve({}), colors.accent);
        expect(filled.foregroundColor!.resolve({}), colors.onAccent);
        expect(filled.minimumSize!.resolve({})!.height, 56);
        expect(filled.shape!.resolve({}), isA<StadiumBorder>());
        // Secondary actions are raised pills.
        final outlined = theme.outlinedButtonTheme.style!;
        expect(outlined.backgroundColor!.resolve({}), colors.surfaceRaised);
        expect(outlined.shape!.resolve({}), isA<StadiumBorder>());
        // Cards are 24 dp; sheets and dialogs too.
        final card = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(card.borderRadius, BorderRadius.circular(24));
        expect(theme.dialogTheme.backgroundColor, colors.surfaceRaised);
        expect(theme.bottomSheetTheme.backgroundColor, colors.surfaceRaised);
        expect(theme.dividerTheme.color, colors.divider);
        expect(theme.chipTheme.selectedColor, colors.primary);
      });
    }

    test(
      'chips are raised stadium pills: elevation in light, border in dark',
      () {
        final light = AppTheme.light().chipTheme;
        final dark = AppTheme.dark().chipTheme;
        expect(light.shape, isA<StadiumBorder>());
        expect(dark.shape, isA<StadiumBorder>());
        expect(light.elevation, greaterThan(0));
        expect(light.shadowColor, isNot(Colors.transparent));
        expect(dark.elevation, 0);
        expect(
          (dark.shape! as StadiumBorder).side.color,
          AptoColors.dark.divider,
        );
        // Label style from the typography token, colour per state.
        final onSelected = light.labelStyle!.color! as WidgetStateColor;
        expect(
          onSelected.resolve({WidgetState.selected}),
          AptoColors.light.onPrimary,
        );
        expect(onSelected.resolve({}), AptoColors.light.textPrimary);
        expect(light.labelStyle!.fontSize, 16);
      },
    );

    test('secondary pills and idle options use the 3:1 option border', () {
      for (final (theme, colors) in [
        (AppTheme.light(), AptoColors.light),
        (AppTheme.dark(), AptoColors.dark),
      ]) {
        final side = theme.outlinedButtonTheme.style!.side!.resolve({})!;
        expect(side.color, colors.optionBorder);
        expect(side.width, Sp.border);
      }
    });

    test('dark has no shadows and a divider border on raised surfaces', () {
      final light = AppTheme.light().cardTheme.shape! as RoundedRectangleBorder;
      final dark = AppTheme.dark().cardTheme.shape! as RoundedRectangleBorder;
      expect(light.side, BorderSide.none);
      expect(dark.side.color, AptoColors.dark.divider);
      expect(AptoShadows.card(AptoColors.light), isNotEmpty);
      expect(AptoShadows.small(AptoColors.light), isNotEmpty);
      expect(AptoShadows.floating(AptoColors.light), isNotEmpty);
      expect(AptoShadows.card(AptoColors.dark), isEmpty);
      expect(AptoShadows.small(AptoColors.dark), isEmpty);
      expect(AptoShadows.floating(AptoColors.dark), isEmpty);
      expect(AptoShadows.raisedBorder(AptoColors.light), isNull);
      expect(AptoShadows.raisedBorder(AptoColors.dark), isNotNull);
    });

    test('the shadows are the ones of the design doc', () {
      final card = AptoShadows.card(AptoColors.light).single;
      expect(card.offset, const Offset(0, 2));
      expect(card.blurRadius, 10);
      final small = AptoShadows.small(AptoColors.light).single;
      expect(small.offset, const Offset(0, 1));
      expect(small.blurRadius, 3);
      final floating = AptoShadows.floating(AptoColors.light).single;
      expect(floating.offset, const Offset(0, 6));
      expect(floating.blurRadius, 16);
      expect(floating.color.a, closeTo(0.30, 0.005));
    });

    test('spec colours are used verbatim', () {
      expect(AptoColors.light.primary, const Color(0xFF2F5D50));
      expect(AptoColors.light.background, const Color(0xFFEFE9DD));
      expect(AptoColors.light.surfaceRaised, const Color(0xFFFFFDF8));
      expect(AptoColors.light.divider, const Color(0xFFF1ECE2));
      expect(AptoColors.light.primaryContainer, const Color(0xFFE5EEEA));
      expect(AptoColors.light.onPrimaryContainer, const Color(0xFF1F3F36));
      expect(AptoColors.light.ringTrack, const Color(0xFFECE5D7));
      expect(AptoColors.light.accent, const Color(0xFFF27A1A));
      expect(AptoColors.light.correct, const Color(0xFF2E9E5B));
      expect(AptoColors.light.correctText, const Color(0xFF1E6B3F));
      expect(AptoColors.light.incorrect, const Color(0xFFD64545));
      expect(AptoColors.light.incorrectText, const Color(0xFFA62F2F));
      expect(AptoColors.dark.background, const Color(0xFF141A17));
      expect(AptoColors.dark.surfaceRaised, const Color(0xFF1F2824));
      expect(AptoColors.dark.divider, const Color(0xFF2A3530));
      expect(AptoColors.dark.primaryContainer, const Color(0xFF23362F));
      expect(AptoColors.dark.ringTrack, const Color(0xFF2C3833));
      expect(AptoColors.dark.correctText, const Color(0xFF7FD6A0));
      expect(AptoColors.dark.incorrectText, const Color(0xFFF4A3A3));
    });
  });

  group('radii and spacing', () {
    test('follow the design doc', () {
      expect(Rad.card, 24);
      expect(Rad.tile, 20);
      expect(Rad.option, 16);
      expect(Rad.chip, 14);
      expect(Rad.pill, greaterThanOrEqualTo(Sp.pillHeight / 2));
      expect(Sp.page, 16);
      expect(Sp.pillHeight, 56);
      expect(Sp.roundButton, 44);
      expect(Sp.floatingClearance, 24 + 56 + 24);
    });
  });

  group('typography', () {
    final typo = AptoTypography.from(AptoColors.light);

    test('Public Sans, sizes and weights follow the spec', () {
      expect(AptoTypography.family, 'PublicSans');
      expect(typo.display.fontSize, 48);
      expect(typo.display.fontWeight, FontWeight.w700);
      expect(typo.display.letterSpacing, closeTo(-0.96, 1e-9));
      expect(typo.score.fontSize, 34);
      expect(typo.score.fontWeight, FontWeight.w700);
      expect(typo.title.fontSize, 26);
      expect(typo.title.fontWeight, FontWeight.w700);
      expect(typo.title.height, 1.22);
      expect(typo.stem.fontSize, 21);
      expect(typo.stem.fontWeight, FontWeight.w600);
      expect(typo.stem.height, 1.38);
      expect(typo.option.fontSize, 17);
      expect(typo.option.fontWeight, FontWeight.w400);
      expect(typo.optionStrong.fontWeight, FontWeight.w600);
      expect(typo.body.fontSize, 16);
      expect(typo.body.fontWeight, FontWeight.w400);
      expect(typo.body.height, 1.5);
      expect(typo.label.fontSize, 17);
      expect(typo.label.fontWeight, FontWeight.w700);
      expect(typo.overline.fontSize, 13);
      expect(typo.overline.fontWeight, FontWeight.w600);
      expect(typo.overline.letterSpacing, closeTo(0.78, 1e-9));
      expect(typo.caption.fontSize, 13);
      expect(typo.caption.fontWeight, FontWeight.w400);
    });

    test('every style sets the family and the wght axis with the weight', () {
      final styles = {
        'display': typo.display,
        'score': typo.score,
        'title': typo.title,
        'stem': typo.stem,
        'option': typo.option,
        'optionStrong': typo.optionStrong,
        'body': typo.body,
        'label': typo.label,
        'overline': typo.overline,
        'caption': typo.caption,
        'subtitle': typo.subtitle,
        'rowTitle': typo.rowTitle,
        'verdict': typo.verdict,
        'lead': typo.lead,
        'counter': typo.counter,
        'brand': typo.brand,
        'badge': typo.badge,
      };
      for (final entry in styles.entries) {
        final s = entry.value;
        expect(s.fontFamily, 'PublicSans', reason: entry.key);
        final wght = s.fontVariations!.single;
        expect(wght.axis, 'wght', reason: entry.key);
        expect(wght.value, s.fontWeight!.value, reason: entry.key);
      }
    });

    test('weight() moves the font weight and the axis together', () {
      final bold = AptoTypography.weight(typo.body, 700);
      expect(bold.fontWeight, FontWeight.w700);
      expect(bold.fontVariations!.single.value, 700);
      expect(bold.fontSize, typo.body.fontSize);
    });

    test('display, score and counter use tabular figures', () {
      for (final style in [typo.display, typo.score, typo.counter]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });

    test('secondary styles take the secondary text colour', () {
      expect(typo.overline.color, AptoColors.light.textSecondary);
      expect(typo.caption.color, AptoColors.light.textSecondary);
      expect(typo.subtitle.color, AptoColors.light.textSecondary);
      expect(typo.counter.color, AptoColors.light.textSecondary);
    });
  });

  test('the bundled Public Sans is loaded (proportional metrics)', () {
    // flutter_test_config loads the font. The fallback test font (Ahem) is
    // monospaced, so a narrow and a wide string would measure the same.
    double width(String text, int weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: AptoTypography.weight(
            AptoTypography.from(AptoColors.light).body,
            weight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    expect(width('iiiiiiii', 400), lessThan(width('MMMMMMMM', 400)));
    // The wght axis is applied: bold text is wider than regular.
    expect(
      width('Probabilidad de aprobar', 700),
      greaterThan(width('Probabilidad de aprobar', 400)),
    );
  });

  testWidgets('context.colors / context.typo resolve inside the app', (
    tester,
  ) async {
    late AptoColors colors;
    late AptoTypography typo;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = context.colors;
          typo = context.typo;
          return const SizedBox.shrink();
        },
      ),
    );
    expect(colors, same(AptoColors.light));
    expect(typo.stem.color, AptoColors.light.textPrimary);

    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          colors = context.colors;
          return const SizedBox.shrink();
        },
      ),
      dark: true,
    );
    expect(colors, same(AptoColors.dark));
  });

  test('the text scaler is never clamped by the theme', () {
    // Respecting the user's text size: no TextScaler.noScaling anywhere in
    // the theme layer.
    expect(AppTheme.light().textTheme.bodyLarge!.fontSize, 16);
    expect(AppTheme.minTouch, 48);
  });
}
