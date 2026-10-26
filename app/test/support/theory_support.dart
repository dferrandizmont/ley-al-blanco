import 'dart:convert';

import 'package:apto_armas/features/content/content_constants.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'db_support.dart';

/// A small `teoria.json` document map: [sections] sections with one paragraph
/// each, unless [sections] is given.
Map<String, dynamic> theoryDocJson(
  String id, {
  String? title,
  int paragraphs = 1,
  List<Map<String, dynamic>>? sections,
}) {
  final tema = const {'practica', 'aem', 'glosario'}.contains(id)
      ? null
      : int.parse(id.substring(1));
  return {
    'id': id,
    'tema': tema,
    'title': title ?? (tema == null ? 'Prueba' : 'Resumen del tema $tema'),
    'summary': 'Resumen de $id.',
    'sections':
        sections ??
        [
          {
            'title': 'Sección de $id',
            'collapsed': false,
            'blocks': [
              for (var i = 0; i < paragraphs; i++)
                {'type': 'p', 'text': 'Párrafo $i de $id.'},
            ],
            'articles': ['Art. 3 RD 137/1993'],
          },
        ],
    'related_questions': ['$id-001'],
  };
}

/// The glossary of the fixture: four sections, 12 terms, some with an article
/// and some with accents (to test the search).
Map<String, dynamic> glossaryFixtureJson() {
  Map<String, dynamic> term(String term, String text, [String? article]) => {
    'term': term,
    'text': text,
    'article': ?article,
  };
  Map<String, dynamic> section(
    String title,
    List<Map<String, dynamic>> items,
  ) => {
    'title': title,
    'collapsed': false,
    'blocks': [
      {'type': 'terms', 'items': items},
    ],
    'articles': <String>[],
  };
  return {
    'id': 'glosario',
    'tema': null,
    'title': 'Glosario',
    'summary': 'Las palabras que más confunden en el examen.',
    'sections': [
      section('Licencias y guías', [
        term(
          'Guía de pertenencia',
          'Documento de cada arma que acredita quién es su titular.',
          'Art. 88 RD 137/1993',
        ),
        term('Licencia D', 'Autoriza armas largas rayadas para caza mayor.'),
        term(
          'Tarjeta europea',
          'Documento para viajar con armas dentro de la UE.',
        ),
      ]),
      section('Piezas del arma', [
        term('Cañón', 'Tubo por el que sale el proyectil.'),
        term('Percutor', 'Pieza que golpea el fulminante del cartucho.'),
        term('Recámara', 'Parte del arma donde se aloja el cartucho.'),
      ]),
      section('Munición', [
        term('Cartucho', 'Conjunto de vaina, pólvora, fulminante y proyectil.'),
        term('Fulminante', 'Carga que inicia la combustión de la pólvora.'),
        term('Perdigón', 'Bolita de plomo de los cartuchos de escopeta.'),
      ]),
      section('Términos legales', [
        term('Depósito', 'Lugar autorizado donde se guardan las armas.'),
        term(
          'Intervención',
          'Retirada de un arma por la autoridad.',
          'Art. 165 RD 137/1993',
        ),
        term('Reserva', 'Parte de la ley que solo puede regular el Estado.'),
      ]),
    ],
    'related_questions': <String>[],
  };
}

/// The fixture used by the theory tests: tema 1 holds every kind of block
/// (and a section that starts folded), tema 2..7 and «La prueba práctica» are
/// short. With [extras], «Autorización para menores (AEM)» and the glossary
/// follow (the real asset ends with them).
Map<String, dynamic> theoryFixtureJson({bool extras = false}) {
  return {
    'edition': kContentEdition,
    'generated_by': 'test',
    'docs': [
      theoryDocJson(
        't1',
        title: 'Funcionamiento y seguridad de las armas',
        sections: [
          {
            'title': 'Cómo se recarga cada arma',
            'collapsed': false,
            'blocks': [
              {'type': 'p', 'text': 'Las armas se distinguen por la recarga.'},
              {
                'type': 'list',
                'items': ['Automática: varios disparos', 'Semiautomática'],
              },
              {
                'type': 'table',
                'caption': 'Tipos de arma',
                'headers': ['Tipo', 'Cómo funciona'],
                'rows': [
                  ['Automática', 'Se recarga sola; ráfaga'],
                  ['De repetición', 'La recargas tú con un mecanismo'],
                ],
              },
              {
                'type': 'key',
                'text': 'Lo que más cae en el examen: la definición de arma.',
              },
              {
                'type': 'notice',
                'text': 'Ojo: el cuestionario dice X; hoy el art. 5 dice Z.',
              },
            ],
            'articles': ['Art. 2.5 RD 137/1993', 'Art. 2.21 RD 137/1993'],
          },
          {
            'title': 'Esquemas de seguridad',
            'collapsed': true,
            'blocks': [
              {
                'type': 'diagram',
                'kind': 'galeria_tiro',
                'caption': 'Galería a 25 metros',
              },
              {'type': 'diagram', 'kind': 'zona_segura'},
              {
                'type': 'diagram',
                'kind': 'secuencia',
                'items': ['Comprueba que está descargada', 'Apunta a la zona'],
              },
            ],
            'articles': ['Anexo II Resolución 1998'],
          },
          {
            'title': 'Mantenimiento',
            'collapsed': false,
            'blocks': [
              {'type': 'p', 'text': 'Limpia el arma después de usarla.'},
            ],
            'articles': ['Art. 2.1 RD 137/1993'],
          },
        ],
      ),
      for (var tema = 2; tema <= 7; tema++) theoryDocJson('t$tema'),
      theoryDocJson('practica', title: 'La prueba práctica de tiro'),
      if (extras) ...[
        theoryDocJson('aem', title: 'Autorización para menores (AEM)'),
        glossaryFixtureJson(),
      ],
    ],
  };
}

Uint8List theoryBytes([Map<String, dynamic>? json]) =>
    Uint8List.fromList(utf8.encode(jsonEncode(json ?? theoryFixtureJson())));

/// The real bank plus a theory asset. By default the manifest carries the
/// checksum of [theory]; the flags build the broken variants.
FakeAssetBundle theoryBundle({
  Map<String, dynamic>? theory,
  bool includeAsset = true,
  bool includeManifestField = true,
  String? wrongSha,

  /// The manifest keeps the checksum of the real bytes but the bundled file
  /// differs by one field.
  bool tamperAsset = false,
}) {
  final bytes = theoryBytes(theory);
  final manifest =
      jsonDecode(utf8.decode(realManifestBytes())) as Map<String, dynamic>;
  manifest.remove('teoria_sha256');
  if (includeManifestField) {
    manifest['teoria_sha256'] = wrongSha ?? sha256.convert(bytes).toString();
  }
  return FakeAssetBundle({
    contentManifestAsset(kContentEdition): Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    ),
    contentQuestionsAsset(kContentEdition): realQuestionsBytes(),
    if (includeAsset)
      contentTheoryAsset(kContentEdition): tamperAsset
          ? theoryBytes(
              (theory ?? theoryFixtureJson())..['generated_by'] = 'otro',
            )
          : bytes,
  });
}

/// An [AssetBundle] that serves [assets] and nothing else (for loader tests
/// that need a manifest without the questions).
AssetBundle bundleOf(Map<String, Uint8List> assets) => FakeAssetBundle(assets);
