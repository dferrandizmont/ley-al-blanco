import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/core/widgets/explanation_body.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/settings_support.dart';

const _label = '¿Ves un error? Avísanos';

const _target = ReportTarget(
  id: 't2-017',
  edition: 'GC-2020-11',
  tema: 2,
  stem: 'Enunciado de prueba',
  answerLetter: 'B',
  explanation: 'Porque lo dice el reglamento.',
  article: 'Art. 3 RD 137/1993',
);

Widget _body({ReportTarget? report = _target, String? notice}) => Scaffold(
  body: SingleChildScrollView(
    child: ExplanationBody(
      correct: false,
      correctLetter: 'B',
      correctText: 'Segunda opción',
      explanation: _target.explanation,
      article: _target.article,
      notice: notice,
      report: report,
    ),
  ),
);

void main() {
  testWidgets('hidden without a support address', (tester) async {
    final launcher = FakeUrlLauncher();
    await pumpApp(
      tester,
      _body(),
      overrides: settingsOverrides(
        launcher: launcher,
        links: const SettingsLinks(),
      ),
    );
    expect(find.text(_label), findsNothing);
    expect(find.byIcon(Icons.flag_rounded), findsNothing);
  });

  testWidgets('hidden when no report target is given', (tester) async {
    await pumpApp(
      tester,
      _body(report: null),
      overrides: settingsOverrides(launcher: FakeUrlLauncher()),
    );
    expect(find.text(_label), findsNothing);
  });

  testWidgets('visible with an address: after the chip, 44 dp, labelled', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      _body(),
      overrides: settingsOverrides(launcher: FakeUrlLauncher()),
    );
    expect(find.text(_label), findsOneWidget);
    expect(find.byIcon(Icons.flag_rounded), findsOneWidget);
    final button = find.widgetWithText(TextButton, _label);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    expect(
      tester.getTopLeft(button).dy,
      greaterThan(tester.getBottomLeft(find.byType(ArticleChip)).dy),
    );
    expect(
      tester.getSemantics(find.text(_label)),
      matchesSemantics(
        label: _label,
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tap opens a mailto with the id, explanation and prompt', (
    tester,
  ) async {
    final launcher = FakeUrlLauncher();
    await pumpApp(
      tester,
      _body(),
      overrides: settingsOverrides(launcher: launcher),
    );
    await tester.tap(find.text(_label));
    await tester.pumpAndSettle();
    expect(launcher.opened, hasLength(1));
    final uri = launcher.opened.single;
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'soporte@ejemplo.es');
    final raw = uri.toString();
    expect(raw, isNot(contains('+')));
    final subject = uri.queryParameters['subject']!;
    expect(subject, 'Error en la pregunta t2-017 · Ley al Blanco 1.2.3 (45)');
    final body = uri.queryParameters['body']!;
    for (final part in [
      't2-017',
      'GC-2020-11',
      'Tema: 2',
      'Enunciado de prueba',
      'Respuesta oficial: B',
      'Porque lo dice el reglamento.',
      'Art. 3 RD 137/1993',
      'Sistema: Android 16',
      '1.2.3 (45)',
      'Cuéntanos qué está mal:',
    ]) {
      expect(body, contains(part));
    }
  });

  testWidgets('a long stem is cut to 200 characters', (tester) async {
    final launcher = FakeUrlLauncher();
    final long = 'x' * 500;
    await pumpApp(
      tester,
      _body(
        report: ReportTarget(
          id: 't1-001',
          edition: 'GC-2020-11',
          tema: 1,
          stem: long,
          answerLetter: 'A',
        ),
      ),
      overrides: settingsOverrides(launcher: launcher),
    );
    await tester.tap(find.text(_label));
    await tester.pumpAndSettle();
    final body = launcher.opened.single.queryParameters['body']!;
    expect(body, contains('x' * 200));
    expect(body, isNot(contains('x' * 201)));
  });

  testWidgets('a failing launcher shows the snack bar', (tester) async {
    await pumpApp(
      tester,
      _body(),
      overrides: settingsOverrides(launcher: FakeUrlLauncher(result: false)),
    );
    await tester.tap(find.text(_label));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('320x568 at 1.3x: notice + explanation + article + button fit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      _body(
        notice: 'Ojo: el cuestionario dice X; tras la reforma de 2023 el art. 5 dice Z.',
      ),
      textScale: 1.3,
      overrides: settingsOverrides(launcher: FakeUrlLauncher()),
    );
    await tester.ensureVisible(find.text(_label));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_label), findsOneWidget);
    final right = tester.getTopRight(find.byType(TextButton)).dx;
    expect(right, lessThanOrEqualTo(320));
  });
}
