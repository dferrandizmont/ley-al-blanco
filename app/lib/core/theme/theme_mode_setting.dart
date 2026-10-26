import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// The user's appearance choice (Ajustes > Apariencia): follow the system,
/// always light or always dark. Kept on this device in the `settings` table
/// under [key]; the app starts with the system mode and switches as soon as the
/// stored value is read (a local query).
class ThemeModeSetting extends Notifier<ThemeMode> {
  /// Key of the `settings` table.
  static const key = 'appearance.theme_mode';

  /// Set once the user picks a mode, so a slow first read cannot overwrite it.
  var _chosen = false;

  @override
  ThemeMode build() {
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(appDatabaseProvider).settingsDao.get(key);
      if (!ref.mounted || _chosen) return;
      state = parse(raw);
    } on Object catch (e) {
      debugPrint('theme mode read failed: ${e.runtimeType}');
    }
  }

  /// Applies [mode] at once and stores it.
  Future<void> set(ThemeMode mode) async {
    _chosen = true;
    state = mode;
    try {
      await ref.read(appDatabaseProvider).settingsDao.set(key, serialize(mode));
    } on Object catch (e) {
      debugPrint('theme mode write failed: ${e.runtimeType}');
    }
  }

  /// The stored text of [mode]: `system`, `light` or `dark`.
  static String serialize(ThemeMode mode) => mode.name;

  /// The mode stored as [raw]; anything unknown or missing is the system.
  static ThemeMode parse(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final themeModeProvider = NotifierProvider<ThemeModeSetting, ThemeMode>(
  ThemeModeSetting.new,
);
