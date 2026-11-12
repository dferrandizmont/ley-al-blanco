import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/theory_loader.dart';
import '../domain/theory.dart';

/// Reads and verifies the bundled theory (`teoria.json`).
final theoryLoaderProvider = Provider<TheoryLoader>(
  (ref) => TheoryLoader(ref.watch(assetBundleProvider)),
);

/// What loading the bundled theory gave: the verified bank, or why there is
/// none ([TheoryStatus]). The loader never throws; an unexpected error still
/// reaches the screens as a provider error and is treated as a failed load.
/// Invalidate it to try again.
final theoryLoadProvider = FutureProvider<TheoryLoadResult>(
  (ref) => ref.watch(theoryLoaderProvider).load(),
);

/// The verified theory, or null when there is none for any reason (see
/// [theoryLoadProvider] for why). A wrong checksum or invalid content never
/// gives a bank.
final theoryProvider = FutureProvider<TheoryBank?>(
  (ref) async => (await ref.watch(theoryLoadProvider.future)).bank,
);

/// True once the theory is loaded and verified (false while loading).
final theoryAvailableProvider = Provider<bool>(
  (ref) => ref.watch(theoryProvider).value != null,
);

/// True when the theory should have loaded and did not (asset missing,
/// checksum that does not match, invalid content or an error): the screens
/// explain it and offer to retry. False while loading, when the theory loaded
/// and when the edition ships none ([TheoryStatus.noManifestEntry]).
bool theoryLoadFailed(AsyncValue<TheoryLoadResult> load) {
  if (load.hasError) return true;
  final status = load.value?.status;
  return status != null &&
      status != TheoryStatus.available &&
      status != TheoryStatus.noManifestEntry;
}

/// Whether Inicio offers Teoría: when it is available, or when it failed to
/// load (so the entry does not vanish and the user can retry). Hidden while
/// loading and when the edition ships no theory.
final theoryEntryVisibleProvider = Provider<bool>((ref) {
  final load = ref.watch(theoryLoadProvider);
  return load.value?.isAvailable == true || theoryLoadFailed(load);
});
