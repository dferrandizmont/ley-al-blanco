import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/theory_loader.dart';
import '../domain/theory.dart';

/// Reads and verifies the bundled theory (`teoria.json`).
final theoryLoaderProvider = Provider<TheoryLoader>(
  (ref) => TheoryLoader(ref.watch(assetBundleProvider)),
);

/// The verified theory, or null when the build has none (asset or manifest
/// entry missing, wrong checksum, invalid content). Never an error: theory is
/// optional, and the Teoría section simply hides.
final theoryProvider = FutureProvider<TheoryBank?>(
  (ref) async => (await ref.watch(theoryLoaderProvider).load()).bank,
);

/// True once the theory is loaded and verified (false while loading).
final theoryAvailableProvider = Provider<bool>(
  (ref) => ref.watch(theoryProvider).value != null,
);
