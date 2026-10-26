import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/diagnostics/crash_reporting.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  // Edge-to-edge: transparent bars, styled per theme in LeyAlBlancoApp.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  installLocalErrorHandling();
  runApp(
    ProviderScope(
      // Failed providers surface their error instead of silently retrying.
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LeyAlBlancoApp(),
    ),
  );
}

/// Adds the bundled font's SIL OFL notice to the licences page.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/PublicSans-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Public Sans'], text);
  });
}
