import 'dart:convert';
import 'dart:io';

import 'package:apto_armas/core/database/app_database.dart';
import 'package:apto_armas/core/providers.dart';
import 'package:apto_armas/features/content/content_constants.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A fresh in-memory database (the caller closes it).
AppDatabase openTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Directory of the bundled bank, relative to `app/` (tests run from there).
final String _bankDir = contentAssetDir(kContentEdition);

Uint8List realQuestionsBytes() =>
    File('$_bankDir/questions.json').readAsBytesSync();

Uint8List realManifestBytes() =>
    File('$_bankDir/manifest.json').readAsBytesSync();

Uint8List realTheoryBytes() => File('$_bankDir/teoria.json').readAsBytesSync();

/// The real bank decoded (a fresh copy each call, safe to mutate).
List<Map<String, dynamic>> realQuestionsJson() =>
    (jsonDecode(utf8.decode(realQuestionsBytes())) as List)
        .cast<Map<String, dynamic>>();

/// An in-memory [AssetBundle] keyed by asset path. Synchronous reads, so it
/// is safe under the fake async of `testWidgets`.
class FakeAssetBundle extends AssetBundle {
  FakeAssetBundle(this.assets);

  /// The real bundled edition (bank and theory), read from disk.
  factory FakeAssetBundle.real() => FakeAssetBundle({
    contentManifestAsset(kContentEdition): realManifestBytes(),
    contentQuestionsAsset(kContentEdition): realQuestionsBytes(),
    contentTheoryAsset(kContentEdition): realTheoryBytes(),
  });

  /// An edition built from [questions] with a matching, valid manifest.
  factory FakeAssetBundle.edition(
    List<Map<String, dynamic>> questions, {
    String edition = kContentEdition,
  }) {
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(questions)));
    final perTema = <String, int>{};
    for (final q in questions) {
      perTema.update('${q['tema']}', (n) => n + 1, ifAbsent: () => 1);
    }
    final manifest =
        jsonDecode(utf8.decode(realManifestBytes())) as Map<String, dynamic>
          ..['edition'] = edition
          ..['question_count'] = questions.length
          ..['per_tema'] = perTema
          ..['questions_sha256'] = sha256.convert(bytes).toString();
    return FakeAssetBundle({
      contentManifestAsset(edition): Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      ),
      contentQuestionsAsset(edition): bytes,
    });
  }

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async {
    final bytes = assets[key];
    if (bytes == null) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(bytes);
  }
}

/// Provider overrides for widget tests: in-memory database, a throwaway
/// the real bundled bank, so the whole bootstrap (import included) runs for
/// real.
///
/// [database] replaces the in-memory one (a file database reopened, say); the
/// caller closes it.
List<Override> databaseTestOverrides({
  AssetBundle? bundle,
  AppDatabase? database,
}) => [
  if (database != null)
    appDatabaseProvider.overrideWithValue(database)
  else
    appDatabaseProvider.overrideWith((ref) {
      final db = openTestDatabase();
      ref.onDispose(db.close);
      return db;
    }),
  assetBundleProvider.overrideWithValue(bundle ?? FakeAssetBundle.real()),
];
