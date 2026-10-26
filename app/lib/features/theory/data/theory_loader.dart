import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show AssetBundle;

import '../../content/content_constants.dart';
import '../domain/theory.dart';

/// Why the theory is (not) available.
enum TheoryStatus {
  /// Loaded and verified.
  available,

  /// The manifest has no `teoria_sha256` (the edition ships no theory yet).
  noManifestEntry,

  /// The manifest announces a theory but `teoria.json` is not in the build, or
  /// the manifest itself could not be read.
  missingAsset,

  /// The bytes of `teoria.json` do not match the manifest's checksum.
  checksumMismatch,

  /// The checksum matches but the content is not valid theory.
  malformed,
}

/// Result of [TheoryLoader.load]: the bank when [status] is
/// [TheoryStatus.available], null otherwise.
class TheoryLoadResult {
  const TheoryLoadResult(this.status, [this.bank]);

  final TheoryStatus status;
  final TheoryBank? bank;

  bool get isAvailable => bank != null;
}

/// Loads the bundled theory (`teoria.json`) and checks its SHA-256 against the
/// manifest, like the importer does for the questions.
///
/// Theory is optional content: a missing asset, a missing manifest field, a
/// wrong checksum or an unreadable file never throw. They all mean "no
/// theory", and the app hides the Teoría section.
class TheoryLoader {
  TheoryLoader(this._bundle, {this.edition = kContentEdition});

  final AssetBundle _bundle;
  final String edition;

  Future<TheoryLoadResult> load() async {
    final String? expected;
    try {
      final manifest = jsonDecode(
        utf8.decode(await _bytes(contentManifestAsset(edition))),
      );
      final raw = manifest is Map ? manifest['teoria_sha256'] : null;
      expected = raw is String && raw.isNotEmpty ? raw.toLowerCase() : null;
    } on Object {
      return const TheoryLoadResult(TheoryStatus.missingAsset);
    }
    if (expected == null) {
      return const TheoryLoadResult(TheoryStatus.noManifestEntry);
    }

    final Uint8List bytes;
    try {
      bytes = await _bytes(contentTheoryAsset(edition));
    } on Object {
      return const TheoryLoadResult(TheoryStatus.missingAsset);
    }
    if (sha256.convert(bytes).toString() != expected) {
      return const TheoryLoadResult(TheoryStatus.checksumMismatch);
    }

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final bank = TheoryBank.fromJson(json);
      if (bank.edition != edition) {
        return const TheoryLoadResult(TheoryStatus.malformed);
      }
      return TheoryLoadResult(TheoryStatus.available, bank);
    } on Object {
      return const TheoryLoadResult(TheoryStatus.malformed);
    }
  }

  /// The exact bytes of an asset (the checksum is over bytes, not text).
  Future<Uint8List> _bytes(String key) async {
    final data = await _bundle.load(key);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
