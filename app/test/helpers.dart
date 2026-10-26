import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/l10n/l10n.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/db_support.dart';

/// Fixed "now" used across widget tests: Thursday 15 Oct 2026, 18:30.
final DateTime kTestNow = DateTime(2026, 10, 15, 18, 30);

/// Pumps [child] in a localized (es) Material app with Riverpod, the app
/// theme and an empty SharedPreferences (or [prefsValues]).
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  bool dark = false,
  double textScale = 1,
  Map<String, Object> prefsValues = const {},
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(() => now ?? kTestNow),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('es'),
        supportedLocales: LeyAlBlancoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, w) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: w!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the whole [LeyAlBlancoApp] (router, bootstrap gate) with the given
/// [overrides], an empty SharedPreferences, an in-memory database and the
/// real bundled question bank (so the bootstrap import runs for real).
Future<void> pumpFullApp(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Map<String, Object> prefsValues = const {},

  /// Replaces the bundled question bank (default: the real one). Riverpod
  /// rejects overriding a provider twice, so pass it here rather than via
  /// [overrides].
  AssetBundle? bundle,

  /// The injected clock (default: fixed at [kTestNow]).
  DateTime Function()? clock,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      retry: (count, error) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        clockProvider.overrideWithValue(clock ?? () => kTestNow),
        ...databaseTestOverrides(bundle: bundle),
        ...overrides,
      ],
      child: const LeyAlBlancoApp(),
    ),
  );
  await tester.pumpAndSettle();
}
