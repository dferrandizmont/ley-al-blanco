import 'package:flutter/widgets.dart';

/// Spacing scale (dp): 2, 4, 8, 12, 16, 20, 24, 32, 40.
class Sp {
  const Sp._();

  /// Hairline gaps (inside the letter circle of an option).
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double x3 = 32;
  static const double x4 = 40;

  /// Screen horizontal padding.
  static const double page = 16;

  /// Gap between cards and between blocks of a screen.
  static const double card = 14;

  /// Gap between larger sections.
  static const double section = 24;

  /// Padding inside the big cards (hero, question, lists).
  static const double cardPad = 20;

  /// Content never grows wider than this (tablets, landscape).
  static const double maxContentWidth = 640;

  /// Minimum touch target (48 dp): every tappable option, button and icon.
  static const double touch = 48;

  /// The visible circle of the small round buttons (close, back, settings):
  /// 44 dp. Only what is drawn: the touch area around it is [touch] (48 dp).
  static const double roundButton = 44;

  /// Gap between the box of a round button ([touch], 48) and the circle it
  /// draws ([roundButton], 44): 2 dp per side.
  static const double roundButtonInset = (touch - roundButton) / 2;

  /// Height of the main pill buttons (radius = half).
  static const double pillHeight = 56;

  /// Distance of the floating "Siguiente" from the bottom edge.
  static const double floatingMargin = 24;

  /// Bottom padding of a scroll view under the floating pill, so nothing
  /// hides behind it.
  static const double floatingClearance =
      floatingMargin + pillHeight + floatingMargin;

  /// Border of a surface or divider (1 dp).
  static const double border = 1;

  /// Border of an option card, the letter circle and the price box (2 dp).
  static const double borderStrong = 2;

  static const EdgeInsets pageInsets = EdgeInsets.symmetric(horizontal: page);

  /// Padding of the top row of a screen (close button, progress bar): the
  /// same on Pregunta, Simulacro and Resultado. On the left it gives up
  /// [roundButtonInset] so the **visible circle** of the close button, not its
  /// 48 dp box, starts at the page margin ([page]) like the cards below it.
  static const EdgeInsets headerInsets = EdgeInsets.fromLTRB(
    page - roundButtonInset,
    s,
    page,
    s,
  );
}

/// Corner radii (dp).
class Rad {
  const Rad._();

  /// Big cards: hero, question, lists, result.
  static const double card = 24;

  /// Tiles (Simulacro / Fallos).
  static const double tile = 20;

  /// Option cards.
  static const double option = 16;

  /// Chips (article chip).
  static const double chip = 14;

  /// Pills: any value >= height / 2 makes a stadium.
  static const double pill = 999;

  /// Bottom sheets and dialogs.
  static const double sheet = 24;

  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get tileRadius => BorderRadius.circular(tile);
  static BorderRadius get optionRadius => BorderRadius.circular(option);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);
}

/// Icon sizes (dp).
class IconSize {
  const IconSize._();

  /// Inline with text (captions, chips).
  static const double inline = 18;

  /// Inside buttons.
  static const double button = 20;

  /// Default (app bar, list leading, option check / cross).
  static const double base = 24;

  /// The glyph of an empty / error state.
  static const double hero = 40;
}

/// Motion durations.
class Motion {
  const Motion._();

  static const Duration state = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 280);
  static const Curve curve = Curves.easeOutCubic;

  /// Zero when the user asked to reduce motion.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false ? Duration.zero : d;
}
