import 'dart:convert';

import 'package:apto_armas/core/l10n/tema_title.dart';
import 'package:apto_armas/features/content/content_constants.dart';
import 'package:apto_armas/features/content/data/content_manifest.dart';
import 'package:apto_armas/features/theory/data/theory_loader.dart';
import 'package:apto_armas/features/theory/domain/theory.dart';
import 'package:apto_armas/l10n/app_localizations_es.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';

import 'support/db_support.dart';
import 'support/theory_support.dart';

void main() {
  group('TheoryBank.fromJson', () {
    test('parses every block type and keeps the document order', () {
      final bank = TheoryBank.fromJson(theoryFixtureJson());
      expect(bank.edition, kContentEdition);
      expect(bank.docs.map((d) => d.id), [
        't1',
        't2',
        't3',
        't4',
        't5',
        't6',
        't7',
        'practica',
      ]);
      expect(bank.temaDocs.map((d) => d.tema), [1, 2, 3, 4, 5, 6, 7]);
      expect(bank.practica?.tema, isNull);
      expect(bank.forTema(3)?.id, 't3');
      expect(bank.byId('nope'), isNull);

      final t1 = bank.forTema(1)!;
      expect(t1.sections, hasLength(3));
      expect(t1.sections[0].collapsed, isFalse);
      expect(t1.sections[1].collapsed, isTrue);
      expect(t1.sections[0].articles, [
        'Art. 2.5 RD 137/1993',
        'Art. 2.21 RD 137/1993',
      ]);
      expect(t1.relatedQuestions, ['t1-001']);

      final blocks = t1.sections[0].blocks;
      expect(blocks[0], isA<ParagraphBlock>());
      expect((blocks[1] as ListBlock).items, hasLength(2));
      final table = blocks[2] as TableBlock;
      expect(table.caption, 'Tipos de arma');
      expect(table.headers, ['Tipo', 'Cómo funciona']);
      expect(table.rows.first, ['Automática', 'Se recarga sola; ráfaga']);
      expect(blocks[3], isA<KeyBlock>());
      expect(blocks[4], isA<NoticeBlock>());

      final diagrams = t1.sections[1].blocks.cast<DiagramBlock>();
      expect(diagrams.map((d) => d.kind), TheoryDiagramKind.values);
      expect(diagrams[0].caption, 'Galería a 25 metros');
      expect(diagrams[2].items, hasLength(2));
    });

    test('the real fields the pipeline strips are not required', () {
      final json = theoryFixtureJson();
      for (final doc in json['docs'] as List) {
        expect((doc as Map).containsKey('confidence'), isFalse);
        expect(doc.containsKey('review_notes'), isFalse);
      }
      expect(() => TheoryBank.fromJson(json), returnsNormally);
    });

    Map<String, dynamic> withDoc0(void Function(Map<String, dynamic> d) edit) {
      final json = theoryFixtureJson();
      edit((json['docs'] as List).first as Map<String, dynamic>);
      return json;
    }

    test('rejects malformed content', () {
      expect(
        () => TheoryBank.fromJson(withDoc0((d) => d['sections'] = [])),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(withDoc0((d) => d['tema'] = 9)),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(withDoc0((d) => d['title'] = '')),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(
          withDoc0((d) {
            ((d['sections'] as List).first as Map)['blocks'] = [
              {'type': 'video', 'text': 'x'},
            ];
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(
          withDoc0((d) {
            ((d['sections'] as List).first as Map)['blocks'] = [
              {
                'type': 'table',
                'headers': ['A', 'B'],
                'rows': [
                  ['1'],
                ],
              },
            ];
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(
          withDoc0((d) {
            ((d['sections'] as List).first as Map)['blocks'] = [
              {'type': 'diagram', 'kind': 'secuencia'},
            ];
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(
          withDoc0((d) {
            ((d['sections'] as List).first as Map)['blocks'] = [
              {'type': 'diagram', 'kind': 'arma'},
            ];
          }),
        ),
        throwsFormatException,
      );
    });

    test('rejects a tema that does not match the document id', () {
      // t1 claiming tema 2, and the practica claiming a tema.
      expect(
        () => TheoryBank.fromJson(withDoc0((d) => d['tema'] = 2)),
        throwsFormatException,
      );
      expect(
        () => TheoryBank.fromJson(withDoc0((d) => d['tema'] = null)),
        throwsFormatException,
      );
      final json = theoryFixtureJson();
      ((json['docs'] as List).last as Map<String, dynamic>)['tema'] = 7;
      expect(() => TheoryBank.fromJson(json), throwsFormatException);
      // An id that is neither tN nor practica is rejected too.
      expect(
        () => TheoryBank.fromJson(withDoc0((d) => d['id'] = 'extra')),
        throwsFormatException,
      );
    });

    test('rejects a duplicated document id', () {
      final json = theoryFixtureJson();
      final docs = json['docs'] as List;
      docs.add(docs.first);
      expect(() => TheoryBank.fromJson(json), throwsFormatException);
    });
  });

  test('ids: t1..t7 map to a tema, practica and anything else do not', () {
    expect(temaOfDocId('t1'), 1);
    expect(temaOfDocId('t7'), 7);
    expect(temaOfDocId('t8'), isNull);
    expect(temaOfDocId('t0'), isNull);
    expect(temaOfDocId('t10'), isNull);
    expect(temaOfDocId(kPracticaDocId), isNull);
    expect(temaDocId(4), 't4');
  });

  test('the key box drops its own title from the text', () {
    String body(String text) => KeyBlock(text).body;
    expect(
      body('Lo que más cae en el examen: la definición.'),
      'la definición.',
    );
    expect(body('Lo que más cae: la definición.'), 'la definición.');
    expect(body('lo que más cae - la definición.'), 'la definición.');
    expect(
      body('La definición es lo que más cae.'),
      'La definición es lo que más cae.',
    );
    expect(body('Lo que más cae:'), 'Lo que más cae:');
    expect(body('Clave para el examen: la definición.'), 'la definición.');
    expect(body('clave para el examen - 16 años.'), '16 años.');
  });

  test('reading time is at least a minute and grows with the text', () {
    final short = TheoryBank.fromJson(theoryFixtureJson()).forTema(2)!;
    expect(short.readingMinutes, 1);
    final long = TheoryDoc.fromJson(
      theoryDocJson('t2', paragraphs: 1)
        ..['sections'] = [
          {
            'title': 'Larga',
            'blocks': [
              {'type': 'p', 'text': 'x' * 400},
              {'type': 'p', 'text': 'x' * 400},
              {'type': 'p', 'text': 'x' * 400},
            ],
          },
        ],
    );
    expect(long.readingMinutes, 2);
  });

  test('the cells of a table count in the reading time', () {
    TheoryDoc doc(List<Map<String, Object?>> blocks) => TheoryDoc.fromJson(
      theoryDocJson('t2', paragraphs: 1)
        ..['sections'] = [
          {'title': 'T', 'blocks': blocks},
        ],
    );
    final table = {
      'type': 'table',
      'headers': ['A', 'B'],
      'rows': [
        for (var i = 0; i < 20; i++) ['x' * 100, 'y' * 100],
      ],
    };
    const paragraph = {'type': 'p', 'text': 'x'};
    expect(TableBlock.fromJson(table).characters, 2 + 20 * 200);
    expect(doc([paragraph]).readingMinutes, 1);
    // 4000 characters of table are 5 minutes, not 1.
    expect(doc([paragraph, table]).readingMinutes, greaterThanOrEqualTo(5));
  });

  test('the manifest reads the optional teoria_sha256', () {
    final manifest =
        jsonDecode(utf8.decode(realManifestBytes())) as Map<String, dynamic>
          ..remove('teoria_sha256');
    expect(ContentManifest.fromJson(manifest).teoriaSha256, isNull);
    manifest['teoria_sha256'] = 'ABC123';
    expect(ContentManifest.fromJson(manifest).teoriaSha256, 'abc123');
  });

  group('TheoryLoader', () {
    Future<TheoryLoadResult> load(AssetBundle bundle) =>
        TheoryLoader(bundle).load();

    test('a checksum that matches loads the bank', () async {
      final result = await load(theoryBundle());
      expect(result.status, TheoryStatus.available);
      expect(result.isAvailable, isTrue);
      expect(result.bank!.docs, hasLength(8));
    });

    test('a wrong checksum is unavailable, not an error', () async {
      final result = await load(theoryBundle(wrongSha: 'a' * 64));
      expect(result.status, TheoryStatus.checksumMismatch);
      expect(result.bank, isNull);
    });

    test(
      'the checksum is over the exact bytes (one changed field fails)',
      () async {
        final result = await load(theoryBundle(tamperAsset: true));
        expect(result.status, TheoryStatus.checksumMismatch);
      },
    );

    test('an announced but missing asset is unavailable', () async {
      final result = await load(theoryBundle(includeAsset: false));
      expect(result.status, TheoryStatus.missingAsset);
      expect(result.bank, isNull);
    });

    test('a manifest without the field is unavailable', () async {
      final result = await load(
        theoryBundle(includeManifestField: false, includeAsset: false),
      );
      expect(result.status, TheoryStatus.noManifestEntry);
      // Even if a file is there: without the checksum it is not trusted.
      final withFile = await load(theoryBundle(includeManifestField: false));
      expect(withFile.status, TheoryStatus.noManifestEntry);
    });

    test('the published teoria.json parses and passes its checksum', () async {
      final result = await load(FakeAssetBundle.real());
      expect(result.status, TheoryStatus.available);
      final bank = result.bank!;
      expect(bank.docs.map((d) => d.id), [
        't1', 't2', 't3', 't4', 't5', 't6', 't7', //
        'practica', 'aem', 'glosario',
      ]);
      expect(bank.edition, kContentEdition);
      expect(bank.temaDocs.map((d) => d.tema), [1, 2, 3, 4, 5, 6, 7]);
      expect(bank.practica, isNotNull);
    });

    test('the published titles of the temas are the official ones of the '
        'ARB (one source of truth)', () async {
      final bank = (await load(FakeAssetBundle.real())).bank!;
      final l10n = AppLocalizationsEs();
      for (final doc in bank.temaDocs) {
        expect(doc.title, l10n.temaTitle(doc.tema!), reason: doc.id);
      }
    });

    test('the published theory keeps units next to their number and has no '
        'repeated key-box title', () async {
      final bank = (await load(FakeAssetBundle.real())).bank!;
      final texts = <String>[];
      for (final doc in bank.docs) {
        for (final section in doc.sections) {
          for (final block in section.blocks) {
            switch (block) {
              case TableBlock():
                texts.addAll(block.rows.expand((row) => row));
              case KeyBlock():
                texts.add(block.text);
                expect(
                  block.text,
                  isNot(startsWith('Lo que más importa')),
                  reason: doc.id,
                );
                expect(
                  block.text,
                  isNot(startsWith('Lo que más se repite')),
                  reason: doc.id,
                );
              case ParagraphBlock():
                texts.add(block.text);
              default:
            }
          }
        }
      }
      final lone = RegExp(r'\d [€%]');
      expect(texts.where(lone.hasMatch), isEmpty);
    });

    test('a build without a theory asset does not fail', () async {
      final result = await load(
        theoryBundle(includeManifestField: false, includeAsset: false),
      );
      expect(result.bank, isNull);
      expect(result.status, TheoryStatus.noManifestEntry);
    });

    test('a matching checksum over invalid content is malformed', () async {
      final result = await load(
        theoryBundle(theory: {'edition': kContentEdition, 'docs': 'nope'}),
      );
      expect(result.status, TheoryStatus.malformed);
    });

    test('a theory of another edition is malformed', () async {
      final result = await load(
        theoryBundle(theory: theoryFixtureJson()..['edition'] = 'OTRA'),
      );
      expect(result.status, TheoryStatus.malformed);
    });

    test('an unreadable manifest is unavailable', () async {
      final result = await load(bundleOf({}));
      expect(result.status, TheoryStatus.missingAsset);
    });
  });
}
