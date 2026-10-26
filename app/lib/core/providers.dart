import 'dart:math' show Random;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/content/content_constants.dart';
import '../features/content/data/content_importer.dart';
import 'database/app_database.dart';
import 'database/daos/settings_dao.dart';

/// Overridden in `main()` with the loaded instance (and in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// Injectable clock (tests pin it).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Injectable random source (mock generation). Tests override it with a
/// seeded `Random`.
final randomProvider = Provider<Random>((ref) => Random());

/// The on-device Drift database, opened on first use and closed with the
/// container. Tests override it with an in-memory one:
/// `appDatabaseProvider.overrideWith((ref) { final db = AppDatabase(
/// NativeDatabase.memory()); ref.onDispose(db.close); return db; })`.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Where bundled assets are read from (tests inject a fake bundle).
final assetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// Imports the bundled question bank (`bootstrapProvider` runs it).
final contentImporterProvider = Provider<ContentImporter>(
  (ref) => ContentImporter(
    ref.watch(appDatabaseProvider),
    ref.watch(assetBundleProvider),
    edition: kContentEdition,
    now: ref.watch(clockProvider),
  ),
);

/// On-device settings shared by study features.
final settingsDaoProvider = Provider<SettingsDao>(
  (ref) => ref.watch(appDatabaseProvider).settingsDao,
);
