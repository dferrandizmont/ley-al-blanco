@Tags(['golden'])
library;

import 'package:apto_armas/app.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/settings_support.dart';

/// Screenshot goldens of Ajustes (docs/design-sereno.md): `ajustes_light` and
/// `ajustes_dark` at 390 wide on a surface tall enough to show the whole
/// screen, `ajustes_small` at 320x568 with the text x1.3 (top of the screen)
/// and `ajustes_small_bottom` (scrolled to the legal notice).
///
/// `ajustes_importar_*` show the dialogs of «Importar progreso» (confirmation
/// and error).
///
/// Regenerate with `flutter test --update-goldens --tags golden
/// --plain-name ajustes`. Goldens are canonical on Windows; elsewhere the
/// comparison is skipped (see `flutter_test_config.dart`).
Future<void> _pumpAjustes(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  bool dark = false,

  FakeProgressFileStore? fileStore,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await pumpFullApp(
    tester,
    overrides: settingsOverrides(
      launcher: FakeUrlLauncher(),
      fileStore: fileStore,
    ),
  );
  await openRoute(tester, '/ajustes');
}

void _golden(
  String file,
  Size size, {
  double scale = 1,
  bool dark = false,

  bool scrollToEnd = false,
}) {
  testWidgets(file, (tester) async {
    try {
      await _pumpAjustes(tester, size: size, scale: scale, dark: dark);
      if (scrollToEnd) {
        await tester.ensureVisible(find.textContaining('Versión 1.2.3'));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(LeyAlBlancoApp),
        matchesGoldenFile('goldens/$file.png'),
      );
    } finally {
      await unmountApp(tester);
    }
  }, tags: ['golden']);
}

/// Opens «Importar progreso» with [picked] and golden-tests the dialog.
void _dialogGolden(
  String file,
  Size size,
  PickedProgressFile picked, {
  double scale = 1,
  bool dark = false,
}) {
  testWidgets(file, (tester) async {
    try {
      await _pumpAjustes(
        tester,
        size: size,
        scale: scale,
        dark: dark,
        fileStore: FakeProgressFileStore(pickResult: picked),
      );
      await tester.ensureVisible(find.text('Importar progreso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar progreso'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(LeyAlBlancoApp),
        matchesGoldenFile('goldens/$file.png'),
      );
    } finally {
      await unmountApp(tester);
    }
  }, tags: ['golden']);
}

void main() {
  const tall = Size(390, 1180);
  _golden('ajustes_light', tall);
  _golden('ajustes_dark', tall, dark: true);

  _golden('ajustes_small', const Size(320, 568), scale: 1.3);
  _golden(
    'ajustes_small_bottom',
    const Size(320, 568),
    scale: 1.3,
    scrollToEnd: true,
  );

  final valid = PickedBytes(
    progressFileBytes(
      attempts: 120,
      srs: 40,
      edit: (j) {
        ((j['attempts'] as List)[0] as Map)['question_id'] = 't9-999';
      },
    ),
  );
  _dialogGolden(
    'ajustes_importar_confirmar_light',
    const Size(390, 844),
    valid,
  );
  _dialogGolden(
    'ajustes_importar_confirmar_dark',
    const Size(390, 844),
    valid,
    dark: true,
  );
  _dialogGolden(
    'ajustes_importar_confirmar_small',
    const Size(320, 568),
    valid,
    scale: 1.3,
  );
  _dialogGolden(
    'ajustes_importar_error_light',
    const Size(390, 844),
    PickedBytes(
      progressFileBytes(
        edit: (j) => ((j['attempts'] as List).first as Map)['selected'] = 'a',
      ),
    ),
  );
}
