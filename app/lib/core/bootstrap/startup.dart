import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../diagnostics/crash_reporting.dart';
import '../l10n/l10n.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../widgets/error_state.dart';

/// Reads the device's preferences (injectable for tests).
typedef PreferencesLoader = Future<SharedPreferences> Function();

/// Sets the system UI mode (injectable for tests).
typedef SystemUiConfigurer = Future<void> Function();

/// Starts the app. What happens before Inicio:
///
/// * The edge-to-edge system UI is cosmetic: if it fails, the app starts
///   anyway.
/// * The preferences are essential. If they cannot be read, a recoverable
///   screen explains it and offers «Reintentar» ([StartupRecoveryApp]); the
///   data of the user is neither touched nor reset.
Future<void> startApp({
  PreferencesLoader loadPreferences = SharedPreferences.getInstance,
  SystemUiConfigurer? configureSystemUi,
  void Function(Widget app) run = runApp,
}) async {
  await _configureSystemUi(configureSystemUi ?? _edgeToEdge);
  installLocalErrorHandling();
  final prefs = await _tryLoad(loadPreferences);
  run(
    prefs != null
        ? buildApp(prefs)
        : StartupRecoveryApp(
            loadPreferences: loadPreferences,
            buildApp: buildApp,
          ),
  );
}

/// The app itself, over the preferences already read.
Widget buildApp(SharedPreferences prefs) => ProviderScope(
  // Failed providers surface their error instead of silently retrying.
  retry: (retryCount, error) => null,
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  child: const LeyAlBlancoApp(),
);

// Edge-to-edge: transparent bars, styled per theme in LeyAlBlancoApp.
Future<void> _edgeToEdge() =>
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

Future<void> _configureSystemUi(SystemUiConfigurer configure) async {
  try {
    await configure();
  } on Object catch (e) {
    debugPrint('system ui mode failed: ${e.runtimeType}');
  }
}

Future<SharedPreferences?> _tryLoad(PreferencesLoader load) async {
  try {
    return await load();
  } on Object catch (e) {
    debugPrint('preferences read failed: ${e.runtimeType}');
    return null;
  }
}

/// Shown when the preferences could not be read at launch: says what
/// happened, that the data is still on the phone, and retries. When the
/// retry works, it becomes the normal app ([buildApp]).
class StartupRecoveryApp extends StatefulWidget {
  const StartupRecoveryApp({
    super.key,
    required this.loadPreferences,
    required this.buildApp,
  });

  final PreferencesLoader loadPreferences;
  final Widget Function(SharedPreferences prefs) buildApp;

  @override
  State<StartupRecoveryApp> createState() => _StartupRecoveryAppState();
}

class _StartupRecoveryAppState extends State<StartupRecoveryApp> {
  Widget? _app;
  var _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    _retrying = true;
    final prefs = await _tryLoad(widget.loadPreferences);
    _retrying = false;
    if (!mounted || prefs == null) return;
    setState(() => _app = widget.buildApp(prefs));
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: LeyAlBlancoApp.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(Theme.of(context).brightness),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: ErrorState(
              title: context.l10n.startupFailedTitle,
              message: context.l10n.startupFailedMessage,
              onRetry: _retry,
            ),
          ),
        ),
      ),
    );
  }
}
