import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/features/content/content_constants.dart';
import 'package:apto_armas/features/content/data/content_importer.dart';
import 'package:apto_armas/features/content/data/content_manifest.dart';
import 'package:apto_armas/features/mock/application/mock_providers.dart';
import 'package:apto_armas/features/mock/domain/mock_config.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'support/db_support.dart';
import 'support/screen_support.dart';
import 'support/study_support.dart';

/// The real bundle with [mock] as the manifest's `mock` block.
FakeAssetBundle bundleWithMock(Object? mock) {
  final bundle = FakeAssetBundle.real();
  final key = contentManifestAsset(kContentEdition);
  final manifest =
      jsonDecode(utf8.decode(bundle.assets[key]!)) as Map<String, dynamic>;
  manifest['mock'] = mock;
  bundle.assets[key] = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
  return bundle;
}

void main() {
  group('manifest mock block', () {
    Map<String, dynamic> manifestJson(Map<String, dynamic>? mock) => {
      'edition': 'E',
      'retrieved': '2026-10-18',
      'source_url': 'https://example.test',
      'question_count': 1,
      'per_tema': {'1': 1},
      'questions_sha256': 'AB',
      'mock': ?mock,
    };

    test('parses size, pass_mark, distribution and avoid_last_mocks', () {
      final m = ContentManifest.fromJson(
        manifestJson({
          'size': 10,
          'pass_mark': 8,
          'distribution': {'1': 4, '2': 6},
          'avoid_last_mocks': 3,
        }),
      );
      expect(m.mock!.size, 10);
      expect(m.mock!.passMark, 8);
      expect(m.mock!.distribution, {1: 4, 2: 6});
      expect(m.mock!.avoidLastMocks, 3);
    });

    test('every key is optional', () {
      final m = ContentManifest.fromJson(manifestJson({}));
      expect(m.mock!.avoidLastMocks, isNull);
      expect(ContentManifest.fromJson(manifestJson(null)).mock, isNull);
    });

    test('mockConfigProvider passes avoid_last_mocks through', () async {
      final c = makeStudyContainer(
        bundle: bundleWithMock({'avoid_last_mocks': 5}),
      );
      final config = await c.read(mockConfigProvider.future);
      expect(config.avoidLastMocks, 5);
      expect((config.size, config.passMark), (20, 16));

      final mock = await c.read(mockServiceProvider).startMock(timed: false);
      expect(mock.config.avoidLastMocks, 5);
    });

    test('avoid_last_mocks 0 means no mock is avoided', () async {
      final c = makeStudyContainer(
        bundle: bundleWithMock({'avoid_last_mocks': 0}),
      );
      expect((await c.read(mockConfigProvider.future)).avoidLastMocks, 0);
    });

    test('without the key the default (2) applies', () async {
      final c = makeStudyContainer(
        bundle: bundleWithMock({'size': 10, 'pass_mark': 8}),
      );
      expect((await c.read(mockConfigProvider.future)).avoidLastMocks, 2);
    });
  });

  group('import validates the mock block', () {
    late AppDatabase db;
    setUp(() => db = openTestDatabase());
    tearDown(() => db.close());

    Future<void> import(Object? mock) =>
        ContentImporter(db, bundleWithMock(mock)).importIfNeeded();

    Future<void> expectRejected(Object? mock, [String? part]) async {
      await expectLater(
        import(mock),
        throwsA(
          isA<ContentIntegrityException>().having(
            (e) => e.message,
            'message',
            part == null ? isNotEmpty : contains(part),
          ),
        ),
      );
      // Nothing was written.
      expect(await db.questionsDao.allActive(), isEmpty);
      expect(await db.settingsDao.get(ContentSettingKeys.sha256), isNull);
    }

    test('a consistent block imports', () async {
      await import({
        'size': 10,
        'pass_mark': 8,
        'distribution': {'1': 5, '2': 5},
        'avoid_last_mocks': 1,
      });
      expect(await db.questionsDao.allActive(), hasLength(423));
    });

    test('pass mark above the size', () async {
      await expectRejected({'size': 10, 'pass_mark': 11}, 'passMark');
    });

    test('the default pass mark (16) does not fit a smaller size', () async {
      await expectRejected({'size': 10}, 'passMark');
    });

    test('size beyond the questions of the bank', () async {
      await expectRejected({'size': 500, 'pass_mark': 400}, 'only 423');
    });

    test('negative avoid_last_mocks', () async {
      await expectRejected({'avoid_last_mocks': -1}, 'avoidLastMocks');
    });

    test('distribution that does not sum to size', () async {
      await expectRejected({
        'distribution': {'1': 5, '2': 5},
      }, 'sums to 10');
    });

    test('distribution asking more than a tema has', () async {
      // Tema 7 has 22 questions.
      await expectRejected({
        'size': 30,
        'pass_mark': 20,
        'distribution': {'7': 30},
      }, 'tema 7 needs 30');
    });

    test('distribution on a tema that does not exist', () async {
      await expectRejected({
        'size': 10,
        'pass_mark': 8,
        'distribution': {'9': 10},
      }, 'tema 9');
    });

    test('wrong types are an unreadable manifest', () async {
      await expectRejected({'size': 'ten'}, 'Unreadable manifest');
    });
  });

  testScreen('the mock intro shows an error state when the exam config fails', (
    tester,
  ) async {
    var broken = true;
    await pumpFullApp(
      tester,
      overrides: [
        mockConfigProvider.overrideWith((ref) async {
          if (broken) throw ArgumentError('bad mock block');
          return MockConfig();
        }),
      ],
    );
    await pushRoute(tester, '/simulacro');

    expect(find.text('No se han podido cargar los datos'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);

    // Retry once the problem is gone: the intro appears.
    broken = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.textContaining('Se aprueba con 16 aciertos'), findsOneWidget);
  });
}
