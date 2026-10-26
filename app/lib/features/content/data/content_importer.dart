import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../../../core/database/app_database.dart';
import '../content_constants.dart';
import '../../mock/domain/mock_allocation.dart';
import '../../mock/domain/mock_config.dart';
import '../domain/question.dart';
import 'content_manifest.dart';

/// The bundled bank is corrupt, tampered with, or inconsistent with its
/// manifest. Nothing was written to the database.
class ContentIntegrityException implements Exception {
  const ContentIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'ContentIntegrityException: $message';
}

enum ImportStatus {
  /// The stored edition and checksum already match: no writes.
  upToDate,

  /// The bank was written (first run or a new edition/checksum).
  imported,
}

class ImportResult {
  const ImportResult({
    required this.status,
    required this.manifest,
    this.inserted = 0,
    this.updated = 0,
    this.retired = 0,
  });

  /// Nothing to do: same edition and checksum as last time.
  const ImportResult.upToDate(ContentManifest manifest)
    : this(status: ImportStatus.upToDate, manifest: manifest);

  final ImportStatus status;
  final ContentManifest manifest;

  /// Questions new to the database.
  final int inserted;

  /// Questions that already existed and were rewritten.
  final int updated;

  /// Questions no longer in the bank, newly flagged retired.
  final int retired;

  bool get isUpToDate => status == ImportStatus.upToDate;

  @override
  String toString() =>
      'ImportResult(${status.name}, +$inserted ~$updated -$retired)';
}

/// Loads the bundled question bank into the database.
///
/// Reads `assets/content/armas/<edition>/{manifest,questions}.json`, checks
/// the SHA-256 of the exact questions bytes against the manifest, and upserts
/// by question id in one transaction. Ids are stable across editions, so
/// attempts and SRS state survive; questions that disappear are flagged
/// retired, never deleted.
class ContentImporter {
  ContentImporter(
    this._db,
    this._bundle, {
    this.edition = kContentEdition,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final AssetBundle _bundle;
  final String edition;
  final DateTime Function() _now;

  Future<ImportResult> importIfNeeded() async {
    final manifest = await _loadManifest();
    final bytes = await _loadBytes(contentQuestionsAsset(edition));

    final actual = sha256.convert(bytes).toString();
    if (actual != manifest.questionsSha256) {
      throw ContentIntegrityException(
        'questions.json checksum mismatch for $edition: '
        'expected ${manifest.questionsSha256}, got $actual',
      );
    }

    final settings = _db.settingsDao;
    if (await settings.get(ContentSettingKeys.edition) == edition &&
        await settings.get(ContentSettingKeys.sha256) == actual) {
      return ImportResult.upToDate(manifest);
    }

    // Parse and validate before opening the transaction: a bad bank throws
    // here and the database is never touched.
    final questions = _parseAndValidate(bytes, manifest);

    return _db.transaction(() async {
      final upserted = await _db.questionsDao.upsertAll(questions);
      final retired = await _db.questionsDao.markRetiredExcept({
        for (final q in questions) q.id,
      });
      await settings.set(ContentSettingKeys.edition, edition);
      await settings.set(ContentSettingKeys.sha256, actual);
      await settings.set(ContentSettingKeys.retrieved, manifest.retrieved);
      await settings.set(
        ContentSettingKeys.importedAt,
        _now().toUtc().toIso8601String(),
      );
      return ImportResult(
        status: ImportStatus.imported,
        manifest: manifest,
        inserted: upserted.inserted,
        updated: upserted.updated,
        retired: retired,
      );
    });
  }

  /// The exact bytes of an asset (the checksum is over bytes, not text).
  Future<Uint8List> _loadBytes(String key) async {
    final data = await _bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<ContentManifest> _loadManifest() async {
    final bytes = await _loadBytes(contentManifestAsset(edition));
    final ContentManifest manifest;
    try {
      manifest = ContentManifest.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
      );
    } on Object catch (e) {
      throw ContentIntegrityException('Unreadable manifest for $edition: $e');
    }
    if (manifest.edition != edition) {
      throw ContentIntegrityException(
        'Manifest edition ${manifest.edition} != expected $edition',
      );
    }
    return manifest;
  }

  List<Question> _parseAndValidate(List<int> bytes, ContentManifest manifest) {
    final List<Question> questions;
    try {
      final raw = jsonDecode(utf8.decode(bytes)) as List;
      questions = [
        for (final item in raw)
          Question.fromJson((item as Map).cast<String, dynamic>()),
      ];
    } on Object catch (e) {
      throw ContentIntegrityException('Unreadable questions.json: $e');
    }

    if (questions.length != manifest.questionCount) {
      throw ContentIntegrityException(
        'Manifest says ${manifest.questionCount} questions, '
        'file has ${questions.length}',
      );
    }
    final seen = <String>{};
    for (final q in questions) {
      if (!seen.add(q.id)) {
        throw ContentIntegrityException('Duplicate question id ${q.id}');
      }
      if (q.options.length != 3) {
        throw ContentIntegrityException(
          '${q.id}: expected 3 options, got ${q.options.length}',
        );
      }
      if (q.answer < 0 || q.answer >= q.options.length) {
        throw ContentIntegrityException(
          '${q.id}: answer ${q.answer} out of range',
        );
      }
      if (q.edition != edition) {
        throw ContentIntegrityException(
          '${q.id}: edition ${q.edition} != $edition',
        );
      }
    }
    _validateMockBlock(manifest, questions);
    return questions;
  }

  /// A manifest with a `mock` block must describe an exam this bank can
  /// actually produce: a consistent config (size, pass mark, distribution,
  /// see [MockConfig]) that the questions of the bank satisfy (enough
  /// questions overall and per tema). Otherwise the mock would silently be
  /// unavailable at run time, so the import fails instead.
  void _validateMockBlock(ContentManifest manifest, List<Question> questions) {
    final mock = manifest.mock;
    if (mock == null) return;
    try {
      final config = MockConfig.withDefaults(
        size: mock.size,
        passMark: mock.passMark,
        distribution: mock.distribution,
        avoidLastMocks: mock.avoidLastMocks,
      );
      final perTema = <int, int>{};
      for (final q in questions) {
        perTema[q.tema] = (perTema[q.tema] ?? 0) + 1;
      }
      allocateByTema(perTema, config);
    } on ArgumentError catch (e) {
      throw ContentIntegrityException(
        'Invalid mock block in the manifest of $edition: $e',
      );
    }
  }
}
