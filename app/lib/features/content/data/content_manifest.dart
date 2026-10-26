import 'package:flutter/foundation.dart' show immutable;

/// Optional `mock` block of a manifest (not in GC-2020-11 yet): the exam
/// shape the bank asks for. Plain values; `features/mock` turns them into its
/// own config.
typedef ManifestMockConfig = ({
  int? size,
  int? passMark,
  Map<int, int>? distribution,
  int? avoidLastMocks,
});

/// `assets/content/armas/<edition>/manifest.json`, reduced to what the app
/// uses. Unknown keys (sources, generated_by, ...) are ignored.
@immutable
class ContentManifest {
  const ContentManifest({
    required this.edition,
    required this.retrieved,
    required this.sourceUrl,
    required this.questionCount,
    required this.perTema,
    required this.questionsSha256,
    this.teoriaSha256,
    this.mock,
  });

  final String edition;

  /// ISO 8601 date the source documents were downloaded.
  final String retrieved;
  final String sourceUrl;
  final int questionCount;

  /// tema -> number of questions.
  final Map<int, int> perTema;

  /// Lower-case hex SHA-256 of the exact bytes of `questions.json`.
  final String questionsSha256;

  /// Lower-case hex SHA-256 of the exact bytes of `teoria.json`; null when the
  /// edition ships no theory (the Teoría section is then hidden).
  final String? teoriaSha256;

  /// Optional exam shape; null when the manifest has no `mock` block.
  final ManifestMockConfig? mock;

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final perTema = json['per_tema'] as Map;
    final mock = json['mock'];
    return ContentManifest(
      edition: json['edition'] as String,
      retrieved: json['retrieved'] as String,
      sourceUrl: json['source_url'] as String,
      questionCount: json['question_count'] as int,
      perTema: Map.unmodifiable({
        for (final e in perTema.entries)
          int.parse(e.key as String): e.value as int,
      }),
      questionsSha256: (json['questions_sha256'] as String).toLowerCase(),
      teoriaSha256: (json['teoria_sha256'] as String?)?.toLowerCase(),
      mock: mock is Map<String, dynamic> ? _parseMock(mock) : null,
    );
  }

  static ManifestMockConfig _parseMock(Map<String, dynamic> json) {
    final distribution = json['distribution'];
    return (
      size: json['size'] as int?,
      passMark: json['pass_mark'] as int?,
      distribution: distribution is Map
          ? Map.unmodifiable({
              for (final e in distribution.entries)
                int.parse('${e.key}'): e.value as int,
            })
          : null,
      avoidLastMocks: json['avoid_last_mocks'] as int?,
    );
  }
}
