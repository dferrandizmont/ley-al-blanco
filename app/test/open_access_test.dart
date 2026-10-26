import 'dart:convert';

import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/application/content_providers.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/quiz/application/figures_cards_controller.dart';
import 'package:apto_armas/features/quiz/application/practice_controller.dart';
import 'package:apto_armas/features/quiz/domain/practice_source.dart';
import 'package:apto_armas/features/progress_transfer/application/progress_transfer_providers.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_codec_runner.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:apto_armas/features/theory/presentation/theory_doc_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/screen_support.dart';
import 'support/settings_support.dart';
import 'support/study_support.dart';

void main() {
  testScreen('new installation opens practice and theory of all seven temas', (
    tester,
  ) async {
    await pumpFullApp(tester);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    for (var tema = 1; tema <= 7; tema++) {
      await openRoute(tester, '/tema/$tema');
      expect(locationOf(tester), '/tema/$tema');
      final session = containerOf(tester)
          .read(practiceControllerProvider(TemaPractice(tema)))
          .requireValue
          .session!;
      expect(session.questions, isNotEmpty);
      expect(session.questions.every((q) => q.tema == tema), isTrue);
      await openRoute(tester, '/teoria/t$tema');
      expect(locationOf(tester), '/teoria/t$tema');
      expect(find.byType(TheoryDocScreen), findsOneWidget);
      expect(find.text('La teoría no está disponible'), findsNothing);
    }
  });

  test(
    'new installation has every figures question and unlimited exams',
    () async {
      final c = makeStudyContainer();
      final bank = await c.read(questionsProvider.future);
      final expected = bank.where((q) => q.isFigures).map((q) => q.id).toSet();
      expect(expected, isNotEmpty);
      final provider = practiceControllerProvider(const FiguresPractice());
      c.listen(provider, (previous, next) {});
      final figures = await c.read(provider.future);
      expect(figures.session!.questions.map((q) => q.id).toSet(), expected);
      c.listen(figuresCardsControllerProvider, (previous, next) {});
      final cards = await c.read(figuresCardsControllerProvider.future);
      expect(cards.pending.map((q) => q.id).toSet(), expected);
      final service = c.read(mockServiceProvider);
      for (var i = 0; i < 8; i++) {
        final mock = await service.startMock(timed: i.isEven);
        expect(mock.questions, hasLength(20));
        expect(mock.questions.map((q) => q.tema).toSet(), {
          1,
          2,
          3,
          4,
          5,
          6,
          7,
        });
      }
      expect(await c.read(mockRepositoryProvider).startedCount(), 8);
    },
  );

  testScreen('all stored exams open their result, review and failures', (
    tester,
  ) async {
    await pumpFullApp(tester);
    final c = containerOf(tester);
    final bank = await bankOf(tester);
    final db = c.read(appDatabaseProvider);
    for (var n = 0; n < 3; n++) {
      final questions = bank
          .where((q) => q.tema >= 4)
          .skip(n)
          .take(20)
          .toList();
      final id = await db.mocksDao.create(
        questionIds: questions.map((q) => q.id).toList(),
        timed: false,
        startedAt: kTestNow,
      );
      await db.mocksDao.finish(
        id,
        answers: List.filled(20, null),
        correctCount: 0,
        passed: false,
        passMark: 16,
        finishedAt: kTestNow.add(const Duration(minutes: 10)),
      );
      await openRoute(tester, '/simulacro/$id');
      for (final suffix in ['resultado', 'revision/0', 'repasar']) {
        final path = '/simulacro/$id/$suffix';
        if (suffix == 'revision/0') {
          await pushRoute(tester, path);
        } else {
          await openRoute(tester, path);
        }
        expect(locationOf(tester), path);
        expect(find.textContaining('Desbloquear'), findsNothing);
      }
    }
  });

  testScreen(
    'settings opens OSS licenses with the application name and version',
    (tester) async {
      await pumpFullApp(
        tester,
        overrides: settingsOverrides(
          launcher: FakeUrlLauncher(),
          links: const SettingsLinks(),
        ),
      );
      await openRoute(tester, '/ajustes');
      expect(find.text('Restaurar compras'), findsNothing);
      expect(find.text('TU COMPRA'), findsNothing);
      expect(find.byType(Switch), findsNothing);
      final licenses = find.text('Licencias de código abierto');
      expect(licenses, findsOneWidget);
      await tester.ensureVisible(licenses);
      await tester.pumpAndSettle();
      await tester.tap(licenses);
      await tester.pumpAndSettle();
      final page = tester.widget<LicensePage>(find.byType(LicensePage));
      expect(page.applicationName, 'Ley al Blanco');
      expect(page.applicationVersion, '1.2.3 (45)');
    },
  );

  test('old progress imports ignore purchase fields and leave legacy DB keys inert', () async {
    final c = makeStudyContainer(
      overrides: [
        progressCodecRunnerProvider.overrideWithValue(
          const InlineProgressCodecRunner(),
        ),
      ],
    );
    await c.read(questionsProvider.future);
    final db = c.read(appDatabaseProvider);
    const legacy = {
      'purchases.entitlement': 'free',
      'purchases.free_mock_used': '1',
      'purchases.free_mock_fingerprint': 'obsolete',
      'purchases.free_mock_finished': '1',
    };
    for (final e in legacy.entries) {
      await db.settingsDao.set(e.key, e.value);
    }
    final bytes = progressFileBytes(
      edit: (json) {
        json['entitlement'] = 'full';
        json['purchases'] = {'entitlement': 'full'};
        (json['settings'] as Map<String, dynamic>).addAll({
          'free_mock_used': true,
          'soft_tema1_shown': true,
          'soft_mock_shown': false,
          'entitlement': 'full',
          'free_mock_fingerprint': 'old',
        });
      },
    );
    final transfer = c.read(progressTransferProvider);
    final plan = await transfer.preview(bytes);
    await transfer.apply(plan);
    expect(await db.attemptsDao.all(), hasLength(3));
    expect(await db.mocksDao.startedCount(), 1);
    for (final e in legacy.entries) {
      expect(await db.settingsDao.get(e.key), e.value);
    }
    final exported =
        jsonDecode(utf8.decode((await transfer.buildExport()).bytes)) as Map;
    expect(exported['settings'], {'theme_mode': 'dark'});
    final mock = await c.read(mockServiceProvider).startMock(timed: false);
    expect(mock.questions, hasLength(20));
    expect(db.schemaVersion, 4);
  });
}
