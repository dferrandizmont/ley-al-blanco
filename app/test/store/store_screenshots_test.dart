@Tags(['store'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apto_armas/app.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/core/theme/apto_colors.dart';
import 'package:apto_armas/core/theme/apto_typography.dart';
import 'package:apto_armas/core/widgets/article_chip.dart';
import 'package:apto_armas/features/mock/application/mock_controller.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/application/mock_service.dart'
    show StartedMock;
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/application/quiz_providers.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import '../support/db_support.dart';
import '../support/screen_support.dart';
import '../support/study_support.dart';
import 'readme_render_support.dart';

/// Marketing screenshots for the stores (Google Play, App Store 6.3", 6.9"
/// and 6.5"). Not part of the normal run: tag `store`, skipped by default
/// (see `dart_test.yaml`). Regenerate with
/// `flutter test --tags store --run-skipped` (full guide in
/// `tool/store/LEEME.md`). PNGs land in `build/store/<target>/NN-<slug>.png`.
///
/// Each image is a brand composition (sand background with a soft `primary`
/// wash, Public Sans caption, the REAL app screen inside a rounded frame).
/// The data is deterministic: in-memory database, the real bank, a fixed
/// clock (Thu 15 Oct 2026, 18:30), seeded random sources and fixed attempts.
/// No weapon is ever drawn and no text says "oficial" (spec §8).
///
/// Every PNG is written **without alpha channel** (RGB, color type 2): App
/// Store and Google Play ask for opaque images, so nothing has to be
/// converted by hand before uploading.

/// Logical size of the app inside the frame; the real pixel size follows the
/// target (device pixel ratio = screen width / [_logicalWidth]).
const double _logicalWidth = 400;
const double _logicalHeight = 780;

class _Target {
  const _Target(this.dir, this.width, this.height);

  final String dir;
  final int width;
  final int height;
}

const _play = _Target('play', 1080, 1920);
// iPhone con Dynamic Island, pantalla mediana: 1206 × 2622, el tamaño que
// App Store Connect pide por defecto (oct-2026).
const _ios63 = _Target('ios63', 1206, 2622);
const _ios69 = _Target('ios69', 1320, 2868);
const _ios65 = _Target('ios65', 1284, 2778);
const _targets = [_play, _ios63, _ios69, _ios65];

class _Shot {
  const _Shot(
    this.file,
    this.caption,
    this.scene, {
    this.sub,
    this.targets = _targets,
    this.dark = false,
  });

  /// `NN-slug` (no extension).
  final String file;

  /// The store caption (store caption script); `\n` only marks where the
  /// line breaks in the picture, the words are the caption's.
  final String caption;
  final String? sub;
  final Future<void> Function(WidgetTester tester) scene;

  final List<_Target> targets;
  final bool dark;
}

// ---------------------------------------------------------------------------
// Scenes
// ---------------------------------------------------------------------------

/// Practice screen on t2-010 («Las armas reglamentadas, se clasifican en:») answered
/// right: verdict, explanation and the article chip in view. The student has
/// already done the first 9 questions of tema 2, so the practice session of
/// the tema resumes at t2-010 (a short stem and short options, so the whole card fits on screen).
Future<void> _scenePractice(WidgetTester tester) async {
  final bank = await bankOf(tester);
  final done = bank
      .where((q) => q.tema == 2)
      .takeWhile((q) => q.id != 't2-010');
  await containerOf(tester).read(studyServiceProvider).recordAnswers([
    for (final q in done)
      attemptOn(
        q,
        correct: true,
        at: kTestNow.subtract(const Duration(days: 3)),
      ),
  ]);
  await tester.pumpAndSettle();
  await pushRoute(tester, '/tema/2');
  final q = containerOf(tester)
      .read(practiceControllerProvider(const TemaPractice(2)))
      .requireValue
      .session!
      .currentQuestion;
  expect(q.id, 't2-010', reason: 'the practice scene is built on t2-010');
  expect(q.explanation, isNotEmpty);
  expect(q.article, isNotNull);
  await tapOption(tester, q.answer);
  await tester.ensureVisible(find.byType(ArticleChip));
  await tester.pumpAndSettle();
}

/// A mock handed in with 18 right and 2 wrong: APTO.
Future<void> _sceneMockApto(WidgetTester tester) async {
  final container = containerOf(tester);
  final started = await container
      .read(mockServiceProvider)
      .startMock(timed: false, rng: Random(3));
  await _answerMock(tester, started, right: 18, wrong: 2);
  await pushRoute(tester, '/simulacro/${started.id}/resultado');
}

Future<void> _answerMock(
  WidgetTester tester,
  StartedMock started, {
  required int right,
  required int wrong,
}) async {
  final container = containerOf(tester);
  final provider = mockControllerProvider(started.id);
  container.listen(provider, (previous, next) {});
  await container.read(provider.future);
  final controller = container.read(provider.notifier);
  for (var i = 0; i < right + wrong; i++) {
    controller.goTo(i);
    final q = started.questions[i];
    controller.select(i < right ? q.answer : wrongOption(q));
  }
  controller.goTo(0);
  await controller.submit();
  await controller.pendingSaves;
}

/// A student well on the way: every tema started, none finished (coverage of
/// 78-94 %), each seen question answered five times over the last five days
/// (an early slip on some, a recent one on very few). Seeded `Random(11)`: the
/// pass probability lands in the 70s and no tema reaches 100 %.
Future<void> _seedProgress(WidgetTester tester) async {
  final bank = await bankOf(tester);
  const coverage = {1: .97, 2: .95, 3: .93, 4: .90, 5: .88, 6: .85, 7: .82};
  final rng = Random(11);
  final attempts = <Attempt>[];
  for (var tema = 1; tema <= 7; tema++) {
    final all = bank.where((q) => q.tema == tema).toList();
    final seen = all.take((all.length * coverage[tema]!).ceil());
    for (final q in seen) {
      final missedEarly = rng.nextDouble() < .04;
      final missedLast = rng.nextDouble() < .025;
      for (final daysAgo in [5, 4, 3, 2, 1]) {
        final correct =
            !((daysAgo == 5 && missedEarly) || (daysAgo == 1 && missedLast));
        attempts.add(
          attemptOn(
            q,
            correct: correct,
            at: kTestNow.subtract(Duration(days: daysAgo)),
          ),
        );
      }
    }
  }
  await containerOf(tester).read(studyServiceProvider).recordAnswers(attempts);
  await tester.pumpAndSettle();
}

Future<void> _sceneHome(WidgetTester tester) => _seedProgress(tester);

/// Fallos: eight failed questions across the seven temas (two in tema 2),
/// each tried before and missed today.
Future<void> _sceneMistakes(WidgetTester tester) async {
  final bank = await bankOf(tester);
  final picks = const [
    (1, 3),
    (2, 8),
    (2, 14),
    (3, 5),
    (4, 9),
    (5, 4),
    (6, 11),
    (7, 6),
  ];
  final attempts = <Attempt>[];
  for (final (tema, n) in picks) {
    final q = bank.where((q) => q.tema == tema).toList()[n];
    attempts.add(
      attemptOn(
        q,
        correct: false,
        at: kTestNow.subtract(Duration(hours: tema)),
      ),
    );
  }
  await containerOf(tester).read(studyServiceProvider).recordAnswers(attempts);
  await tester.pumpAndSettle();
  await pushRoute(tester, '/fallos');
}

Future<void> _sceneTheory(WidgetTester tester) => pushRoute(tester, '/teoria');

const _shots = [
  _Shot(
    '01-preguntas-explicadas',
    'Las 423 preguntas,\nexplicadas',
    _scenePractice,
    sub: 'Con su artículo del BOE',
  ),
  _Shot(
    '02-simulacro',
    'Simulacro real:\n20 preguntas,\napto con 16',
    _sceneMockApto,
  ),
  _Shot('03-probabilidad', 'Tu probabilidad\nde aprobar', _sceneHome),
  _Shot('04-fallos', 'Repasa tus fallos', _sceneMistakes),
  _Shot('05-gratis', 'Gratis.\nSin anuncios.', _sceneTheory),
  _Shot(
    '03-probabilidad-oscuro',
    'Tu probabilidad\nde aprobar',
    _sceneHome,
    targets: [_play],
    dark: true,
  ),
];

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

/// Frame geometry for one [_Target].
class _Layout {
  _Layout(this.target) {
    final w = target.width.toDouble();
    final h = target.height.toDouble();
    captionSize = (w * .078).roundToDouble();
    subSize = (captionSize * .5).roundToDouble();
    bezel = (w * .011).roundToDouble();
    cornerScreen = (w * .052).roundToDouble();
    final topPad = h * .04;
    captionBlock = captionSize * _lineHeight * 3 + 20 + subSize * 1.3;
    gap = h * .02;
    topZone = topPad + captionBlock + gap;
    final bottom = h * .035;
    final availH = h - topZone - bottom - 2 * bezel;
    final availW = w * .78 - 2 * bezel;
    var sw = min(availH / (_logicalHeight / _logicalWidth), availW);
    // A multiple of 20 so that sw * 780 / 400 is an integer.
    sw = (sw / 20).floorToDouble() * 20;
    screenW = sw.round();
    screenH = screenW * 39 ~/ 20; // = screenW * 780 / 400, exact
    pixelRatio = sw / _logicalWidth;
    // Centre the frame in what is left under the caption.
    final room = h - topZone - bottom;
    frameTop = topZone + (room - (screenH + 2 * bezel)) / 2;
    this.topPad = topPad;
  }

  static const _lineHeight = 1.12;

  final _Target target;
  late final double captionSize;
  late final double subSize;
  late final double bezel;
  late final double cornerScreen;
  late final double captionBlock;
  late final double topPad;
  late final double topZone;
  late final double gap;
  late final int screenW;
  late final int screenH;
  late final double pixelRatio;
  late final double frameTop;
}

/// Pumps the whole app at the screen size of [layout] with a seeded database.
Future<GlobalKey> _pumpApp(
  WidgetTester tester,
  _Layout layout, {
  required bool dark,
}) async {
  tester.view.physicalSize = Size(
    layout.screenW.toDouble(),
    layout.screenH.toDouble(),
  );
  tester.view.devicePixelRatio = layout.pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ProviderScope(
        retry: (count, error) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          clockProvider.overrideWithValue(() => kTestNow),
          randomProvider.overrideWithValue(Random(7)),
          ...databaseTestOverrides(),
        ],
        child: const LeyAlBlancoApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

/// Draws the brand composition around [screen] and returns it as a PNG
/// without alpha channel (RGB), the format both stores ask for.
Future<Uint8List> _compose({
  required ui.Image screen,
  required _Layout layout,
  required AptoColors colors,
  required String caption,
  required String name,
  String? sub,
}) async {
  final w = layout.target.width.toDouble();
  final h = layout.target.height.toDouble();
  final isLight = colors.brightness == Brightness.light;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  // Background: sand, with a soft primary wash fading out under the caption.
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..color = colors.background,
  );
  final washHeight = layout.topZone + layout.screenH * .18;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, washHeight),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, washHeight), [
        colors.primary.withValues(alpha: isLight ? .20 : .10),
        colors.primary.withValues(alpha: 0),
      ]),
  );

  // Caption (Public Sans bold) and optional sub-caption, centred in the zone.
  final captionPainter = TextPainter(
    text: TextSpan(
      text: caption,
      style: TextStyle(
        fontFamily: AptoTypography.family,
        fontSize: layout.captionSize,
        fontWeight: FontWeight.w700,
        height: _Layout._lineHeight,
        color: colors.textPrimary,
        letterSpacing: -layout.captionSize * .01,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 3,
  )..layout(maxWidth: w * .86);
  assert(
    !captionPainter.didExceedMaxLines,
    'caption "$caption" does not fit in 3 lines',
  );
  TextPainter? subPainter;
  if (sub != null) {
    subPainter = TextPainter(
      text: TextSpan(
        text: sub,
        style: TextStyle(
          fontFamily: AptoTypography.family,
          fontSize: layout.subSize,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: w * .86);
  }
  final textHeight =
      captionPainter.height + (subPainter == null ? 0 : 20 + subPainter.height);
  final zone = layout.topZone - layout.topPad;
  var y = layout.topPad + (zone - layout.gap - textHeight) / 2;
  captionPainter.paint(canvas, Offset((w - captionPainter.width) / 2, y));
  y += captionPainter.height + 20;
  subPainter?.paint(canvas, Offset((w - subPainter.width) / 2, y));

  // Frame: a plain rounded rectangle, a soft shadow and the real screen.
  final frameW = layout.screenW + 2 * layout.bezel;
  final frameH = layout.screenH + 2 * layout.bezel;
  final frame = RRect.fromRectAndRadius(
    Rect.fromLTWH((w - frameW) / 2, layout.frameTop, frameW, frameH),
    Radius.circular(layout.cornerScreen + layout.bezel),
  );
  canvas.drawRRect(
    frame.shift(Offset(0, h * .008)),
    Paint()
      ..color = colors.scrim.withValues(alpha: isLight ? .28 : .6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .02),
  );
  canvas.drawRRect(
    frame,
    Paint()..color = isLight ? colors.textPrimary : colors.outline,
  );
  final screenRect = Rect.fromLTWH(
    frame.left + layout.bezel,
    frame.top + layout.bezel,
    layout.screenW.toDouble(),
    layout.screenH.toDouble(),
  );
  canvas.save();
  canvas.clipRRect(
    RRect.fromRectAndRadius(screenRect, Radius.circular(layout.cornerScreen)),
  );
  canvas.drawImageRect(
    screen,
    Rect.fromLTWH(0, 0, screen.width.toDouble(), screen.height.toDouble()),
    screenRect,
    Paint()..filterQuality = FilterQuality.high,
  );
  canvas.restore();

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    layout.target.width,
    layout.target.height,
  );
  try {
    // PNG opaco (color type 2): ni App Store ni Google Play admiten alfa.
    return await encodePng(image, name: name);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  for (final shot in _shots) {
    for (final target in shot.targets) {
      testWidgets(
        '${target.dir}/${shot.file}',
        (tester) async {
          final layout = _Layout(target);
          try {
            final key = await _pumpApp(tester, layout, dark: shot.dark);
            await shot.scene(tester);
            await tester.pumpAndSettle();
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final colors = shot.dark ? AptoColors.dark : AptoColors.light;

            final png = await tester.runAsync(() async {
              final screen = await boundary.toImage(
                pixelRatio: layout.pixelRatio,
              );
              // toImage rounds up: float noise may add one pixel.
              expect(screen.width, closeTo(layout.screenW, 1));
              expect(screen.height, closeTo(layout.screenH, 1));
              final bytes = await _compose(
                screen: screen,
                layout: layout,
                colors: colors,
                caption: shot.caption,
                name: '${target.dir}/${shot.file}.png',
                sub: shot.sub,
              );
              screen.dispose();
              // IHDR: 8 bits por canal y color type 2 (RGB, sin canal alfa).
              expect(bytes[24], 8, reason: '8 bits por canal');
              expect(bytes[25], 2, reason: 'PNG RGB sin canal alfa');
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              expect(frame.image.width, target.width);
              expect(frame.image.height, target.height);
              frame.image.dispose();
              codec.dispose();
              return bytes;
            });

            final out = File('build/store/${target.dir}/${shot.file}.png');
            out.parent.createSync(recursive: true);
            out.writeAsBytesSync(png!);
            // Las cinco escenas claras de Play también se versionan para el
            // README, reducidas a la mitad con el codec de Flutter.
            if (target == _play && !shot.dark) {
              await tester.runAsync(() async {
                final codec = await ui.instantiateImageCodec(
                  png,
                  targetWidth: 540,
                  targetHeight: 960,
                );
                final frame = await codec.getNextFrame();
                try {
                  expect(frame.image.width, 540);
                  expect(frame.image.height, 960);
                  await writeReadmePng(frame.image, '${shot.file}.png');
                } finally {
                  frame.image.dispose();
                  codec.dispose();
                }
              });
            }
          } finally {
            await unmountApp(tester);
          }
        },
        tags: ['store'],
        timeout: const Timeout(Duration(minutes: 3)),
      );
    }
  }
}
