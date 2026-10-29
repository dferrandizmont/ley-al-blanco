import 'package:flutter/foundation.dart' show immutable;

/// The theory summaries of an edition, as published in `teoria.json`
/// (docs/teoria-guia.md): one document per tema (`t1`..`t7`) plus
/// «La prueba práctica» (`practica`), the minors' authorisation (`aem`) and
/// the glossary (`glosario`). Plain text and block lists: the app draws the
/// tables and diagrams, nothing here is an image.
@immutable
class TheoryBank {
  const TheoryBank({required this.edition, required this.docs});

  final String edition;

  /// Stable order: t1..t7, practica, aem, glosario (the last two may be
  /// missing from older builds).
  final List<TheoryDoc> docs;

  factory TheoryBank.fromJson(Map<String, dynamic> json) {
    final raw = json['docs'];
    if (raw is! List) throw const FormatException('`docs` must be a list');
    final docs = [
      for (final item in raw) TheoryDoc.fromJson(_asMap(item, 'doc')),
    ];
    final seen = <String>{};
    for (final doc in docs) {
      if (!seen.add(doc.id)) {
        throw FormatException('Duplicate theory document ${doc.id}');
      }
    }
    return TheoryBank(edition: _string(json, 'edition'), docs: docs);
  }

  /// The document with [id] (`t3`, `practica`), or null.
  TheoryDoc? byId(String id) {
    for (final doc in docs) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  /// The summary of tema [tema] (1..7), or null.
  TheoryDoc? forTema(int tema) => byId(temaDocId(tema));

  /// «La prueba práctica», or null.
  TheoryDoc? get practica => byId(kPracticaDocId);

  /// «Autorización para menores (AEM)», or null.
  TheoryDoc? get aem => byId(kAemDocId);

  /// The glossary, or null.
  TheoryDoc? get glosario => byId(kGlosarioDocId);

  /// The tema summaries in tema order (without the documents that have no
  /// tema).
  List<TheoryDoc> get temaDocs => [
    for (final doc in docs)
      if (doc.tema != null) doc,
  ]..sort((a, b) => a.tema!.compareTo(b.tema!));
}

/// Id of «La prueba práctica».
const String kPracticaDocId = 'practica';

/// Id of «Autorización para menores (AEM)».
const String kAemDocId = 'aem';

/// Id of the glossary.
const String kGlosarioDocId = 'glosario';

/// The free documents that belong to no tema (`tema` is null).
const Set<String> kTemalessDocIds = {kPracticaDocId, kAemDocId, kGlosarioDocId};

/// `t3` for tema 3.
String temaDocId(int tema) => 't$tema';

/// The tema (1..7) of a document id (`t3`), or null for anything else
/// (including the documents without tema: `practica`, `aem`, `glosario`).
int? temaOfDocId(String id) {
  final match = RegExp(r'^t([1-7])$').firstMatch(id);
  return match == null ? null : int.parse(match.group(1)!);
}

/// One page: a tema summary, «La prueba práctica», the AEM or the glossary.
@immutable
class TheoryDoc {
  const TheoryDoc({
    required this.id,
    required this.tema,
    required this.title,
    required this.summary,
    required this.sections,
    this.relatedQuestions = const [],
  });

  /// `t1`..`t7`, `practica`, `aem` or `glosario`.
  final String id;

  /// 1..7, null for the documents without tema (see [kTemalessDocIds]).
  final int? tema;
  final String title;
  final String summary;
  final List<TheorySection> sections;

  /// Ids of the bank questions this text helps answer.
  final List<String> relatedQuestions;

  factory TheoryDoc.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'];
    if (sections is! List || sections.isEmpty) {
      throw const FormatException('`sections` must be a non-empty list');
    }
    final tema = json['tema'];
    if (tema != null && (tema is! int || tema < 1 || tema > 7)) {
      throw FormatException('`tema` must be 1..7 or null, got $tema');
    }
    final id = _string(json, 'id');
    if (tema != (kTemalessDocIds.contains(id) ? null : temaOfDocId(id))) {
      throw FormatException('`tema` $tema does not match the document id $id');
    }
    final related = json['related_questions'];
    return TheoryDoc(
      id: id,
      tema: tema as int?,
      title: _string(json, 'title'),
      summary: _string(json, 'summary'),
      sections: [
        for (final s in sections) TheorySection.fromJson(_asMap(s, 'section')),
      ],
      relatedQuestions: related is List
          ? [for (final q in related) q as String]
          : const [],
    );
  }

  /// Approximate reading time in whole minutes (at least 1), from the text of
  /// the document at ~900 characters a minute.
  int get readingMinutes {
    var chars = summary.length;
    for (final section in sections) {
      chars += section.title.length;
      for (final block in section.blocks) {
        chars += block.characters;
      }
    }
    return (chars / _charsPerMinute).ceil().clamp(1, 99);
  }

  /// True when the document has a «Clave para el examen» box.
  bool get hasExamKey => sections.any(
    (section) => section.blocks.any((block) => block is KeyBlock),
  );

  /// The summary without its own «Clave para el examen:» prefix (the box
  /// below already carries that title), with the sentence that follows in
  /// upper case: «…se presta. la guía…» reads «…se presta. La guía…».
  String get summaryWithoutExamKey {
    final match = _examKeyPrefix.firstMatch(summary);
    if (match == null) return summary;
    final rest = summary.substring(match.end).trimLeft();
    if (rest.isEmpty) return summary;
    return '${summary.substring(0, match.start)}'
        '${upperCaseFirstLetter(rest)}';
  }

  static const int _charsPerMinute = 900;

  /// The «Clave para el examen:» a summary may repeat before its own box.
  static final RegExp _examKeyPrefix = RegExp(
    r'\bclave para el examen:\s*',
    caseSensitive: false,
  );
}

/// A titled group of blocks, foldable in the reader.
@immutable
class TheorySection {
  const TheorySection({
    required this.title,
    required this.blocks,
    this.collapsed = false,
    this.articles = const [],
  });

  final String title;

  /// Starts folded (long tables).
  final bool collapsed;
  final List<TheoryBlock> blocks;

  /// Sources of the section, e.g. `Art. 3 RD 137/1993`.
  final List<String> articles;

  /// [articles] that no glossary term of this section already carries as its
  /// own article: those would only repeat the chips drawn under each term.
  /// For a section without terms it is [articles] unchanged.
  List<String> get articlesNotInTerms {
    final own = <String>{
      for (final block in blocks)
        if (block is TermsBlock)
          for (final item in block.items)
            if (item.article != null) item.article!,
    };
    return [
      for (final article in articles)
        if (!own.contains(article)) article,
    ];
  }

  factory TheorySection.fromJson(Map<String, dynamic> json) {
    final blocks = json['blocks'];
    if (blocks is! List || blocks.isEmpty) {
      throw const FormatException('`blocks` must be a non-empty list');
    }
    final articles = json['articles'];
    return TheorySection(
      title: _string(json, 'title'),
      collapsed: json['collapsed'] == true,
      blocks: [
        for (final b in blocks) TheoryBlock.fromJson(_asMap(b, 'block')),
      ],
      articles: articles is List
          ? [for (final a in articles) a as String]
          : const [],
    );
  }
}

/// What a diagram draws.
enum TheoryDiagramKind {
  /// Shooting stand, firing line and a target at 25 m.
  galeriaTiro('galeria_tiro'),

  /// A firing sector with the safe direction of the muzzle.
  zonaSegura('zona_segura'),

  /// Numbered steps (uses [DiagramBlock.items]).
  secuencia('secuencia');

  const TheoryDiagramKind(this.json);

  final String json;

  static TheoryDiagramKind parse(String value) {
    for (final kind in values) {
      if (kind.json == value) return kind;
    }
    throw FormatException('Unknown diagram kind $value');
  }
}

/// One piece of a section.
sealed class TheoryBlock {
  const TheoryBlock();

  factory TheoryBlock.fromJson(Map<String, dynamic> json) {
    return switch (_string(json, 'type')) {
      'p' => ParagraphBlock(_string(json, 'text')),
      'list' => ListBlock(_strings(json, 'items')),
      'table' => TableBlock.fromJson(json),
      'key' => KeyBlock(_string(json, 'text')),
      'notice' => NoticeBlock(_string(json, 'text')),
      'diagram' => DiagramBlock.fromJson(json),
      'terms' => TermsBlock.fromJson(json),
      final other => throw FormatException('Unknown block type $other'),
    };
  }

  /// Characters of text, for the reading time.
  int get characters;
}

/// A short paragraph.
@immutable
class ParagraphBlock extends TheoryBlock {
  const ParagraphBlock(this.text);

  final String text;

  @override
  int get characters => text.length;
}

/// A bulleted list.
@immutable
class ListBlock extends TheoryBlock {
  const ListBlock(this.items);

  final List<String> items;

  @override
  int get characters => items.fold(0, (sum, item) => sum + item.length);
}

/// A table of 2..4 columns; every row has as many cells as [headers].
@immutable
class TableBlock extends TheoryBlock {
  const TableBlock({required this.headers, required this.rows, this.caption});

  final String? caption;
  final List<String> headers;
  final List<List<String>> rows;

  factory TableBlock.fromJson(Map<String, dynamic> json) {
    final headers = _strings(json, 'headers');
    final rows = json['rows'];
    if (headers.length < 2) {
      throw const FormatException('A table needs at least 2 columns');
    }
    if (rows is! List || rows.isEmpty) {
      throw const FormatException('`rows` must be a non-empty list');
    }
    final parsed = [
      for (final row in rows) [for (final cell in row as List) cell as String],
    ];
    for (final row in parsed) {
      if (row.length != headers.length) {
        throw FormatException(
          'Table row has ${row.length} cells, expected ${headers.length}',
        );
      }
    }
    return TableBlock(
      caption: json['caption'] as String?,
      headers: headers,
      rows: parsed,
    );
  }

  /// The text of the headers and of every cell: tables are read too, so they
  /// count in the reading time (docs/teoria-guia.md).
  @override
  int get characters =>
      headers.fold(0, (sum, h) => sum + h.length) +
      rows.fold(
        0,
        (sum, row) => sum + row.fold(0, (rowSum, cell) => rowSum + cell.length),
      );
}

/// The «Clave para el examen» box.
@immutable
class KeyBlock extends TheoryBlock {
  const KeyBlock(this.text);

  final String text;

  /// [text] without a leading «Clave para el examen:» (or the former
  /// «Lo que más cae:» / «Lo que más cae en el examen:» still present in the
  /// content sources); the box already carries that title.
  String get body {
    final stripped = text.replaceFirst(_titlePrefix, '').trimLeft();
    if (stripped.isEmpty) return text;
    return upperCaseFirstLetter(stripped);
  }

  static final RegExp _titlePrefix = RegExp(
    r'^\s*(clave para el examen|lo que más cae( en el examen)?)\s*[:.\-–—]\s*',
    caseSensitive: false,
  );

  @override
  int get characters => text.length;
}

/// The first letter of [text] in upper case, the rest of the text as it is.
///
/// It respects the Spanish letters with an accent and the ñ, and it leaves
/// the opening punctuation in front of the letter («¿», «¡», ««», «"», «'»,
/// «(», «[»).
String upperCaseFirstLetter(String text) => text.replaceFirstMapped(
  _initialLetter,
  (match) => '${match[1]}${match[2]!.toUpperCase()}',
);

/// The first letter of a text and the punctuation that may come before it.
final RegExp _initialLetter = RegExp(
  r'''^([\s"'«“‘¿¡(\[]*)([a-záéíóúüñ])''',
  caseSensitive: false,
);

/// A reform notice (the current law differs from the questionnaire).
@immutable
class NoticeBlock extends TheoryBlock {
  const NoticeBlock(this.text);

  final String text;

  @override
  int get characters => text.length;
}

/// A drawing made by the app (never a picture, never a weapon or a person).
@immutable
class DiagramBlock extends TheoryBlock {
  const DiagramBlock({required this.kind, this.caption, this.items = const []});

  final TheoryDiagramKind kind;
  final String? caption;

  /// The steps of a [TheoryDiagramKind.secuencia]; empty for the others.
  final List<String> items;

  factory DiagramBlock.fromJson(Map<String, dynamic> json) {
    final kind = TheoryDiagramKind.parse(_string(json, 'kind'));
    final items = json['items'] is List
        ? _strings(json, 'items')
        : const <String>[];
    if (kind == TheoryDiagramKind.secuencia && items.isEmpty) {
      throw const FormatException('A secuencia needs `items`');
    }
    return DiagramBlock(
      kind: kind,
      caption: json['caption'] as String?,
      items: items,
    );
  }

  @override
  int get characters => items.fold(0, (sum, item) => sum + item.length);
}

/// One glossary entry: the term, its definition and, optionally, the article
/// it comes from (same format as a section's `articles`).
@immutable
class TermItem {
  const TermItem({required this.term, required this.text, this.article});

  final String term;
  final String text;
  final String? article;

  factory TermItem.fromJson(Map<String, dynamic> json) {
    final article = json['article'];
    if (article != null && (article is! String || article.trim().isEmpty)) {
      throw const FormatException('`article` must be a non-empty string');
    }
    return TermItem(
      term: _string(json, 'term'),
      text: _string(json, 'text'),
      article: article as String?,
    );
  }

  /// True when every word of [query] (already folded with [foldForSearch])
  /// appears in the term or its definition, ignoring case and accents.
  bool matches(List<String> queryWords) {
    if (queryWords.isEmpty) return true;
    final haystack = foldForSearch('$term $text');
    return queryWords.every(haystack.contains);
  }
}

/// A list of definitions (the glossary), shown as «term, text, article».
@immutable
class TermsBlock extends TheoryBlock {
  const TermsBlock(this.items);

  final List<TermItem> items;

  factory TermsBlock.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List || items.isEmpty) {
      throw const FormatException('`items` must be a non-empty list');
    }
    return TermsBlock([
      for (final item in items) TermItem.fromJson(_asMap(item, 'term')),
    ]);
  }

  @override
  int get characters =>
      items.fold(0, (sum, i) => sum + i.term.length + i.text.length);
}

/// Lower case without Spanish accents (á é í ó ú ü) and with the ñ folded to
/// n, for searching: someone typing «canon» on a keyboard without ñ must find
/// «cañón». (In a weapons glossary the pairs that this merges, such as
/// «año»/«ano», do not give useful false hits.)
String foldForSearch(String input) {
  const from = 'áàâäéèêëíìîïóòôöúùûüñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}

/// The words of a search query, folded with [foldForSearch].
List<String> searchWords(String query) => [
  for (final w in foldForSearch(query).split(RegExp(r'\s+')))
    if (w.isNotEmpty) w,
];

extension TheoryDocSearch on TheoryDoc {
  /// Number of glossary terms in the document.
  int get termCount {
    var count = 0;
    for (final section in sections) {
      for (final block in section.blocks) {
        if (block is TermsBlock) count += block.items.length;
      }
    }
    return count;
  }

  /// The document reduced to the terms that match [query]: only the sections
  /// with at least one match survive, unfolded and with just those terms
  /// (the section's article chips are dropped: they refer to the whole
  /// section, not to the terms left). Null when nothing matches.
  /// An empty [query] returns the document unchanged.
  TheoryDoc? filterTerms(String query) {
    final words = searchWords(query);
    if (words.isEmpty) return this;
    final kept = <TheorySection>[];
    for (final section in sections) {
      final blocks = <TheoryBlock>[
        for (final block in section.blocks)
          if (block is TermsBlock)
            if ([
                  for (final i in block.items)
                    if (i.matches(words)) i,
                ]
                case final hits when hits.isNotEmpty)
              TermsBlock(hits),
      ];
      if (blocks.isNotEmpty) {
        kept.add(TheorySection(title: section.title, blocks: blocks));
      }
    }
    if (kept.isEmpty) return null;
    return TheoryDoc(
      id: id,
      tema: tema,
      title: title,
      summary: summary,
      sections: kept,
      relatedQuestions: relatedQuestions,
    );
  }
}

Map<String, dynamic> _asMap(Object? value, String what) {
  if (value is! Map) throw FormatException('Expected an object for $what');
  return value.cast<String, dynamic>();
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('`$key` must be a non-empty string');
  }
  return value;
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('`$key` must be a non-empty list');
  }
  return [for (final item in value) item as String];
}
