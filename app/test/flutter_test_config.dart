import 'dart:async';
import 'dart:io' show File, Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData> _bytesOf(File file) async =>
    ByteData.view(file.readAsBytesSync().buffer);

/// Loads the bundled Public Sans and the Material icon font (flutter_test does
/// not register fonts) so layouts and goldens use the real typography and
/// real icons instead of the test font's boxes.
Future<void> _loadFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final publicSans = FontLoader('PublicSans')
    ..addFont(_bytesOf(File('assets/fonts/PublicSans-Variable.ttf')));
  await publicSans.load();

  // The icon font ships with the Flutter SDK.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')..addFont(_bytesOf(icons));
      await loader.load();
    }
  }
}

/// Goldens are canonical on Windows only. Font rasterisation differs on macOS
/// and Linux (2-4 % pixel diffs), so on those hosts the comparison is skipped
/// (always passes) while the widget tree still builds and renders. On Windows
/// the default comparator stays in place, so a golden mismatch still fails.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await _loadFonts();
  if (!Platform.isWindows) {
    goldenFileComparator = _SkipGoldenComparator();
  }
  await testMain();
}

class _SkipGoldenComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async => true;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}
