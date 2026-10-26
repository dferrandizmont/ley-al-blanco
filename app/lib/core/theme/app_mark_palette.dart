import 'package:flutter/material.dart';

/// Colours of the brand mark. [AppMarkPalette.icon] is the exact palette of the
/// app icon and the splash; The in-app mark derives a themed one from the design
/// tokens (so the in-app mark keeps the >= 3:1 contrast checked in
/// `theme_contrast_test`).
@immutable
class AppMarkPalette {
  const AppMarkPalette({
    required this.background,
    required this.track,
    required this.arc,
    required this.shield,
    required this.check,
  });

  /// Full-bleed square behind the mark.
  final Color background;

  /// Decorative empty part of the ring.
  final Color track;

  /// Progress arc (80 %).
  final Color arc;

  /// Shield fill.
  final Color shield;

  /// Check on the shield.
  final Color check;

  /// Mountain green `#2F5D50`, track `#3E6E60`, safety orange `#F27A1A`,
  /// sand `#EFE9DD`. Source of truth for the launcher icon and the splash.
  static const icon = AppMarkPalette(
    background: Color(0xFF2F5D50),
    track: Color(0xFF3E6E60),
    arc: Color(0xFFF27A1A),
    shield: Color(0xFFEFE9DD),
    check: Color(0xFF2F5D50),
  );

  /// Shield fill shared by every themed palette (sand, 6.2:1 on the tile).
  static const shieldSand = Color(0xFFEFE9DD);

  /// White silhouette used by monochrome launcher icons.
  static const monochromeInk = Color(0xFFFFFFFF);

  /// Themed palette for in-app use: [tile] is `brandTile`, [arc] the theme
  /// `accent`. The track is the tile lightened by an 8 % white veil (about
  /// `#3E6E60` on `#2F5D50`).
  factory AppMarkPalette.themed({required Color tile, required Color arc}) {
    return AppMarkPalette(
      background: tile,
      track: Color.alphaBlend(const Color(0x14FFFFFF), tile),
      arc: arc,
      shield: shieldSand,
      check: tile,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppMarkPalette &&
      other.background == background &&
      other.track == track &&
      other.arc == arc &&
      other.shield == shield &&
      other.check == check;

  @override
  int get hashCode => Object.hash(background, track, arc, shield, check);
}
