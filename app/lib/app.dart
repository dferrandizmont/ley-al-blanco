import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'core/l10n/l10n.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_setting.dart';
import 'core/widgets/error_state.dart';
import 'features/progress/presentation/progress_warmup.dart';

class LeyAlBlancoApp extends ConsumerWidget {
  const LeyAlBlancoApp({super.key});

  /// Spanish only for now.
  static const supportedLocales = [Locale('es')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      routerConfig: router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      locale: const Locale('es'),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(Theme.of(context).brightness),
        child: BootstrapGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Blocks the UI until [bootstrapProvider] finished: a spinner while it runs,
/// an error state with "Reintentar" when it fails.
class BootstrapGate extends ConsumerWidget {
  const BootstrapGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootstrapProvider);
    return boot.when(
      data: (_) => ProgressWarmup(child: child),
      loading: () => const _SettingUp(),
      error: (e, _) => Scaffold(
        body: ErrorState(
          title: context.l10n.bootstrapFailed,
          onRetry: () => ref.invalidate(bootstrapProvider),
        ),
      ),
    );
  }
}

/// Splash while the bootstrap runs.
class _SettingUp extends StatelessWidget {
  const _SettingUp();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: Sp.l),
            Text(
              context.l10n.bootstrapLoading,
              style: context.typo.body.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
