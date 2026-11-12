import 'package:apto_armas/core/bootstrap/startup.dart';
import 'package:apto_armas/core/widgets/error_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/screen_support.dart';

/// P15: a failure before Inicio is explained and can be retried; the system UI
/// mode is cosmetic and never stops the app.
const _title = 'No se ha podido iniciar la app';

/// A loader that fails [failures] times and then works.
class _Loader {
  _Loader({required this.failures});

  int failures;
  int calls = 0;

  Future<SharedPreferences> call() async {
    calls++;
    if (failures > 0) {
      failures--;
      throw PlatformException(code: 'unavailable');
    }
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }
}

const _marker = Key('normal-app');

Widget _fakeApp(SharedPreferences prefs) =>
    const SizedBox(key: _marker, width: 1, height: 1);

/// startApp installs the local error handlers: put the test's back afterwards.
void _restoreHandlersAfterTest() {
  final onError = FlutterError.onError;
  final dispatcherOnError = PlatformDispatcher.instance.onError;
  addTearDown(() {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = dispatcherOnError;
  });
}

void main() {
  group('startApp', () {
    testWidgets('runs the app when the preferences load', (tester) async {
      _restoreHandlersAfterTest();
      final loader = _Loader(failures: 0);
      Widget? ran;
      await startApp(
        loadPreferences: loader.call,
        configureSystemUi: () async {},
        run: (app) => ran = app,
      );
      expect(ran, isNotNull);
      expect(ran, isNot(isA<StartupRecoveryApp>()));
      expect(loader.calls, 1);
    });

    testWidgets('a failing system UI mode does not stop the app', (
      tester,
    ) async {
      _restoreHandlersAfterTest();
      Widget? ran;
      await startApp(
        loadPreferences: _Loader(failures: 0).call,
        configureSystemUi: () async =>
            throw PlatformException(code: 'no-activity'),
        run: (app) => ran = app,
      );
      expect(ran, isNotNull);
      expect(ran, isNot(isA<StartupRecoveryApp>()));
    });

    testWidgets('runs the recovery screen when the preferences fail', (
      tester,
    ) async {
      _restoreHandlersAfterTest();
      Widget? ran;
      await startApp(
        loadPreferences: _Loader(failures: 1).call,
        configureSystemUi: () async {},
        run: (app) => ran = app,
      );
      expect(ran, isA<StartupRecoveryApp>());
    });
  });

  group('StartupRecoveryApp', () {
    testScreen('explains the failure and keeps the data safe', (tester) async {
      await tester.pumpWidget(
        StartupRecoveryApp(
          loadPreferences: _Loader(failures: 5).call,
          buildApp: _fakeApp,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
      expect(find.textContaining('Tus datos siguen en el móvil'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reintentar'), findsOneWidget);
      expect(find.byKey(_marker), findsNothing);
    });

    testScreen('a retry that fails again keeps the screen', (tester) async {
      final loader = _Loader(failures: 5);
      await tester.pumpWidget(
        StartupRecoveryApp(loadPreferences: loader.call, buildApp: _fakeApp),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(loader.calls, 1);
      expect(find.text(_title), findsOneWidget);
      expect(find.byKey(_marker), findsNothing);
    });

    testScreen('a retry that works starts the normal app', (tester) async {
      // The screen is already showing the failure: the retry is the next call.
      final loader = _Loader(failures: 0);
      await tester.pumpWidget(
        StartupRecoveryApp(loadPreferences: loader.call, buildApp: _fakeApp),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reintentar'));
      await tester.pumpAndSettle();
      expect(find.byKey(_marker), findsOneWidget);
      expect(find.text(_title), findsNothing);
      expect(find.byType(ErrorState), findsNothing);
    });

    testScreen('also works at 320 dp, large text and dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        StartupRecoveryApp(
          loadPreferences: _Loader(failures: 5).call,
          buildApp: _fakeApp,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
