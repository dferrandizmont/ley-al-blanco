import 'dart:async';

import 'package:apto_armas/core/bootstrap/app_bootstrap.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/theme/apto_colors.dart';
import 'package:apto_armas/core/theme/spacing.dart';
import 'package:apto_armas/core/theme/theme_mode_setting.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/settings_support.dart';

const _legal =
    'App independiente y no oficial. Preguntas basadas en el cuestionario '
    'publicado por la Dirección General de la Guardia Civil (consultado el '
    '18/10/2026). Las explicaciones son de redacción propia y no '
    'constituyen asesoramiento jurídico.';

void _phone(WidgetTester tester, {double textScale = 1}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

/// Opens `/ajustes` on a phone. Returns the launcher that records the links.
Future<FakeUrlLauncher> _pump(
  WidgetTester tester, {
  SettingsLinks links = kTestLinks,
  FakeUrlLauncher? launcher,
  Map<String, Object> prefs = const {},
}) async {
  _phone(tester);
  final fake = launcher ?? FakeUrlLauncher();
  await pumpFullApp(
    tester,
    prefsValues: prefs,
    overrides: settingsOverrides(launcher: fake, links: links),
  );
  await openRoute(tester, '/ajustes');
  return fake;
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _scrollTo(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

ThemeMode _themeMode(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testScreen(
    'leaving settings while support loads the version cancels safely',
    (tester) async {
      _phone(tester);
      final version = Completer<AppInfo>();
      final launcher = FakeUrlLauncher();
      await pumpFullApp(
        tester,
        overrides: [
          settingsLinksProvider.overrideWithValue(kTestLinks),
          urlLauncherProvider.overrideWithValue(launcher),
          appInfoProvider.overrideWith((ref) => version.future),
        ],
      );
      await openRoute(tester, '/ajustes');
      await _tap(tester, find.text('Escribir a soporte'));
      await openRoute(tester, '/');
      version.complete(const AppInfo(version: '1.2.3'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(launcher.opened, isEmpty);
    },
  );

  group('APARIENCIA', () {
    testScreen('follows the system by default; choosing a mode applies it at '
        'once and stores it', (tester) async {
      await _pump(tester);
      expect(_themeMode(tester), ThemeMode.system);

      await _tap(tester, find.text('Oscuro'));
      expect(_themeMode(tester), ThemeMode.dark);
      final dao = containerOf(tester).read(appDatabaseProvider).settingsDao;
      expect(await dao.get('appearance.theme_mode'), 'dark');

      await _tap(tester, find.text('Claro'));
      expect(_themeMode(tester), ThemeMode.light);
      expect(await dao.get('appearance.theme_mode'), 'light');

      await _tap(tester, find.text('Sistema'));
      expect(_themeMode(tester), ThemeMode.system);
      expect(await dao.get('appearance.theme_mode'), 'system');
    });

    testScreen('a stored mode is applied when the setting is read', (
      tester,
    ) async {
      await _pump(tester);
      final container = containerOf(tester);
      await container
          .read(appDatabaseProvider)
          .settingsDao
          .set(ThemeModeSetting.key, 'dark');
      container.invalidate(themeModeProvider);
      await tester.pumpAndSettle();
      expect(_themeMode(tester), ThemeMode.dark);
    });

    testScreen('the three options are one radio group with the chosen one '
        'checked, each at least 48 dp tall', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      await _tap(tester, find.text('Claro'));

      for (final (label, checked) in [
        ('Sistema', false),
        ('Claro', true),
        ('Oscuro', false),
      ]) {
        final finder = find.bySemanticsLabel(label);
        expect(
          tester.getSemantics(finder),
          isSemantics(
            label: label,
            hasCheckedState: true,
            isChecked: checked,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
          ),
          reason: label,
        );
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      }
      expect(
        find.bySemanticsLabel('Tema de la app'),
        findsOneWidget,
        reason: 'the group has a name',
      );
      semantics.dispose();
    });
  });

  group('APARIENCIA at large text', () {
    /// The three option texts, in order.
    List<Finder> options() => [
      find.text('Sistema'),
      find.text('Claro'),
      find.text('Oscuro'),
    ];

    testScreen('side by side the three texts share one line and one size', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.text('Sistema'));
      final tops = {for (final o in options()) tester.getTopLeft(o).dy};
      expect(tops, hasLength(1), reason: 'one row');
      final sizes = {for (final o in options()) tester.getSize(o).height};
      expect(sizes, hasLength(1), reason: 'one text size');
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsNothing);
    });

    testScreen('at 320 dp and x2 the options stack as a list: same size, one '
        'under the other, each at least 48 dp tall', (tester) async {
      await _pump(tester);
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Oscuro'));
      expect(tester.takeException(), isNull);

      final rects = [for (final o in options()) tester.getRect(o)];
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top, greaterThan(rects[i - 1].bottom));
        expect(rects[i].left, rects[0].left, reason: 'aligned');
        expect(rects[i].height, rects[0].height, reason: 'one text size');
      }
      // A radio icon marks the choice without colour alone: the stacked
      // list shows a filled one for the chosen option (Sistema).
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.radio_button_unchecked_rounded),
        findsNWidgets(2),
      );

      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      expect(_themeMode(tester), ThemeMode.dark);
    });

    testScreen('the chosen segment has a primary border', (tester) async {
      await _pump(tester);
      await _tap(tester, find.text('Claro'));
      final colors = AptoColors.light;
      BoxBorder? borderOf(String label) {
        final container = tester.widget<AnimatedContainer>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          ),
        );
        return (container.decoration as BoxDecoration?)?.border;
      }

      final chosen = borderOf('Claro')! as Border;
      expect(chosen.top.color, colors.primary);
      expect(chosen.top.width, Sp.borderStrong);
      final other = borderOf('Oscuro')! as Border;
      expect(other.top.color, Colors.transparent);
    });
  });

  group('BANCO DE PREGUNTAS', () {
    testScreen('shows edition, the real question count and the date, and '
        'opens the source in an external app', (tester) async {
      final launcher = await _pump(tester);
      final manifest = containerOf(tester)
          .read(bootstrapProvider)
          .requireValue
          .manifest;

      expect(find.text('BANCO DE PREGUNTAS'), findsOneWidget);
      expect(find.text('Cuestionario GC nov-2020'), findsOneWidget);
      expect(find.text('${manifest.questionCount}'), findsOneWidget);
      expect(find.text('18 oct 2026'), findsOneWidget);

      await _tap(tester, find.text('Ver la fuente original'));
      expect(launcher.opened, [Uri.parse(manifest.sourceUrl)]);
    });

    testScreen('a launcher that cannot open the link says so', (tester) async {
      final launcher = FakeUrlLauncher(result: false);
      await _pump(tester, launcher: launcher);
      await _tap(tester, find.text('Ver la fuente original'));
      expect(launcher.opened, hasLength(1));
      expect(find.text('No se ha podido abrir el enlace.'), findsOneWidget);
    });
  });

  group('AYUDA', () {
    testScreen('support opens a mailto with the app and system versions only', (
      tester,
    ) async {
      final launcher = await _pump(tester);
      expect(find.text('AYUDA'), findsOneWidget);
      expect(find.text('Respondemos en menos de 48 h'), findsOneWidget);

      await _tap(tester, find.text('Escribir a soporte'));
      final uri = launcher.opened.single;
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'soporte@ejemplo.es');
      expect(uri.queryParameters['subject'], 'Ley al Blanco 1.2.3 (45)');
      expect(
        uri.queryParameters['body'],
        '\n\n---\nApp: Ley al Blanco 1.2.3 (45)\nSistema: Android 16',
      );
      expect(
        uri.toString(),
        contains('subject=Ley%20al%20Blanco%201.2.3%20(45)'),
      );
      expect(uri.toString(), isNot(contains('+')));
    });

    testScreen('the privacy policy opens in an external app', (tester) async {
      final launcher = await _pump(tester);
      await _tap(tester, find.text('Política de privacidad'));
      expect(launcher.opened, [Uri.parse('https://ejemplo.es/privacidad')]);
    });

    testScreen('without support links the licenses section stays available', (
      tester,
    ) async {
      await _pump(tester, links: const SettingsLinks());
      expect(find.text('AYUDA'), findsOneWidget);
      expect(find.text('Escribir a soporte'), findsNothing);
      expect(find.text('Política de privacidad'), findsNothing);
      // The rest of the screen is intact.
      expect(find.text('Licencias de código abierto'), findsOneWidget);
      expect(find.text('BANCO DE PREGUNTAS'), findsOneWidget);
    });

    testScreen('each row is hidden on its own when only the other is set', (
      tester,
    ) async {
      await _pump(
        tester,
        links: const SettingsLinks(supportEmail: 'soporte@ejemplo.es'),
      );
      expect(find.text('Escribir a soporte'), findsOneWidget);
      expect(find.text('Política de privacidad'), findsNothing);
      await unmountApp(tester);

      await _pump(
        tester,
        links: const SettingsLinks(privacyUrl: 'https://ejemplo.es/p'),
      );
      expect(find.text('Escribir a soporte'), findsNothing);
      expect(find.text('Política de privacidad'), findsOneWidget);
    });
  });

  group('pie', () {
    testScreen('shows the fixed legal notice with the date and the version', (
      tester,
    ) async {
      await _pump(tester);
      await _scrollTo(tester, find.text('Versión 1.2.3 (45)'));
      expect(find.text(_legal), findsOneWidget);
      expect(find.text('Versión 1.2.3 (45)'), findsOneWidget);
    });
  });

  group('pantalla pequeña', () {
    testScreen('320x568 at 1.3x: no overflow, everything reachable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpFullApp(
        tester,
        overrides: settingsOverrides(launcher: FakeUrlLauncher()),
      );
      await openRoute(tester, '/ajustes');

      for (final text in [
        'Sistema',
        'Claro',
        'Oscuro',
        'Licencias de código abierto',
        'Cuestionario GC nov-2020',
        'Ver la fuente original',
        'Escribir a soporte',
        'Política de privacidad',
        'Versión 1.2.3 (45)',
      ]) {
        await _scrollTo(tester, find.text(text));
        final rect = tester.getRect(find.text(text));
        expect(rect.left, greaterThanOrEqualTo(0), reason: text);
        expect(rect.right, lessThanOrEqualTo(320), reason: text);
      }
      // Tap targets stay at least 44 dp.
      for (final text in ['Sistema', 'Claro', 'Oscuro']) {
        expect(
          tester.getSize(find.bySemanticsLabel(text)).height,
          greaterThanOrEqualTo(44),
          reason: text,
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('helpers', () {
    test('SettingsLinks only accepts a plain address and an http(s) URL', () {
      expect(const SettingsLinks().hasAny, isFalse);
      expect(const SettingsLinks(supportEmail: '  ').support, isNull);
      expect(const SettingsLinks(supportEmail: 'sin-arroba').support, isNull);
      expect(const SettingsLinks(supportEmail: 'a b@c.es').support, isNull);
      expect(const SettingsLinks(supportEmail: ' a@b.es ').support, 'a@b.es');
      for (final bad in [
        '',
        'ejemplo.es',
        'javascript:alert(1)',
        'ftp://x.es',
      ]) {
        expect(SettingsLinks(privacyUrl: bad).privacy, isNull, reason: bad);
      }
      expect(
        const SettingsLinks(privacyUrl: 'https://ejemplo.es/p').privacy,
        Uri.parse('https://ejemplo.es/p'),
      );
    });

    test('systemLabel adds a clean version to the platform name only', () {
      expect(systemLabel('Android', '16'), 'Android 16');
      expect(systemLabel('Android', ' 9 '), 'Android 9');
      expect(systemLabel('iOS', '18.2.1'), 'iOS 18.2.1');
      // Nothing that is not a version goes into the mail.
      expect(systemLabel('Android', null), 'Android');
      expect(systemLabel('Android', ''), 'Android');
      expect(systemLabel('Android', 'Pixel 9 Pro'), 'Android');
      expect(systemLabel('Android', '16\nSistema: x'), 'Android');
      expect(systemLabel('Android', '1' * 40), 'Android');
    });

    test('iosVersionOf reads the version out of the system string', () {
      expect(iosVersionOf('Version 18.2 (Build 22C150)'), '18.2');
      expect(iosVersionOf('Version 17.5.1 (Build 21F90)'), '17.5.1');
      expect(iosVersionOf('Version 16 (Build 20A)'), '16');
      expect(iosVersionOf('algo raro'), isNull);
    });

    test('without the native channel the label falls back to the name', () {
      final container = ProviderContainer(
        overrides: [platformNameProvider.overrideWithValue('Android')],
      );
      addTearDown(container.dispose);
      expect(container.read(systemLabelProvider.future), completion('Android'));
    });

    test('supportMailUri encodes spaces as %20 and keeps the address', () {
      final uri = supportMailUri(
        'a@b.es',
        subject: 'Ley al Blanco 1',
        body: 'Línea 1\nLínea 2',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'a@b.es');
      expect(uri.queryParameters['subject'], 'Ley al Blanco 1');
      expect(uri.queryParameters['body'], 'Línea 1\nLínea 2');
      expect(
        uri.toString(),
        startsWith('mailto:a@b.es?subject=Ley%20al%20Blanco'),
      );
    });

    test('ThemeModeSetting stores and parses the three modes', () {
      for (final mode in ThemeMode.values) {
        expect(ThemeModeSetting.parse(ThemeModeSetting.serialize(mode)), mode);
      }
      expect(ThemeModeSetting.parse(null), ThemeMode.system);
      expect(ThemeModeSetting.parse('verde'), ThemeMode.system);
    });

    test('AppInfo label', () {
      expect(
        const AppInfo(version: '1.0.0', buildNumber: '7').label,
        '1.0.0 (7)',
      );
      expect(const AppInfo(version: '1.0.0').label, '1.0.0');
    });
  });
}
