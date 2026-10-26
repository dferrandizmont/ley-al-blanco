import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/iso.dart';
import '../../../core/providers.dart';
import '../../../core/theme/theme_mode_setting.dart';
import '../../content/content_constants.dart';
import '../../mock/application/mock_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../data/progress_codec_runner.dart';
import '../data/progress_file_store.dart';
import '../data/progress_transfer_repository.dart';
import '../domain/progress_codec.dart';
import '../domain/progress_snapshot.dart';

/// The system file dialogs. Tests (and the integration battery) override it:
/// the native picker cannot be driven from Dart.
final progressFileStoreProvider = Provider<ProgressFileStore>(
  (ref) => const SystemProgressFileStore(),
);

/// Where the codec runs: another isolate (parsing a big file would drop
/// frames). Widget tests override it with the inline runner, because a real
/// isolate cannot finish under the fake clock of `testWidgets`.
final progressCodecRunnerProvider = Provider<ProgressCodecRunner>(
  (ref) => const IsolateProgressCodecRunner(),
);

final progressTransferRepositoryProvider = Provider<ProgressTransferRepository>(
  (ref) => ProgressTransferRepository(ref.watch(appDatabaseProvider)),
);

/// The file ready to be written: its suggested name and its bytes.
class ProgressExport {
  const ProgressExport({required this.fileName, required this.bytes});

  /// `ley-al-blanco-progreso-2026-10-20.json`.
  final String fileName;
  final Uint8List bytes;
}

/// The progress would not fit in a file the app itself can import back
/// ([kMaxProgressFileBytes]): nothing is written.
class ProgressExportTooLargeException implements Exception {
  const ProgressExportTooLargeException();

  @override
  String toString() => 'ProgressExportTooLargeException';
}

/// Exports and imports the progress (Ajustes > Tus datos).
///
/// Nothing leaves the phone except the file the user saves where they choose;
/// nothing is read except the file they pick. Importing is validated in full
/// ([ProgressCodec.parse], [ProgressCodec.reconcile]) before a single row is
/// touched and then written in one transaction.
class ProgressTransfer {
  ProgressTransfer(this._ref);

  final Ref _ref;

  /// `ley-al-blanco-progreso-AAAA-MM-DD.json` for [now] (local date).
  static String fileNameFor(DateTime now) =>
      'ley-al-blanco-progreso-${toIsoDate(now)}.json';

  /// Builds the export of the current progress.
  Future<ProgressExport> buildExport() async {
    final now = _ref.read(clockProvider)();
    var version = '';
    try {
      version = (await _ref.read(appInfoProvider.future)).version;
    } on Object {
      // Unknown: the file is still valid, the field just says so.
    }
    final snapshot = await _ref
        .read(progressTransferRepositoryProvider)
        .read(
          edition: kContentEdition,
          appVersion: version.isEmpty ? 'unknown' : version,
          exportedAt: now,
        );
    final bytes = await _ref.read(progressCodecRunnerProvider).encode(snapshot);
    if (bytes.length > kMaxProgressFileBytes) {
      // Would not import back: better to say so now.
      throw const ProgressExportTooLargeException();
    }
    return ProgressExport(fileName: fileNameFor(now), bytes: bytes);
  }

  /// Exports to a file the user picks. False when they cancelled.
  Future<bool> export() async {
    final built = await buildExport();
    return _ref
        .read(progressFileStoreProvider)
        .save(fileName: built.fileName, bytes: built.bytes);
  }

  /// Validates [bytes] and checks them against the question bank. Throws
  /// [ProgressImportException] when the file must not be imported; nothing is
  /// written either way.
  Future<ProgressImportPlan> preview(Uint8List bytes) async {
    final mockSize = (await _ref.read(mockConfigProvider.future)).size;
    final snapshot = await _ref
        .read(progressCodecRunnerProvider)
        .parse(bytes, now: _ref.read(clockProvider)(), mockSize: mockSize);
    final bank = await _ref.read(progressTransferRepositoryProvider).bank();
    return ProgressCodec.reconcile(snapshot, bank);
  }

  /// Writes [plan] (all or nothing) and refreshes everything that shows
  /// progress, so no restart is needed.
  Future<void> apply(ProgressImportPlan plan) async {
    await _ref
        .read(progressTransferRepositoryProvider)
        .replaceWith(plan.snapshot);
    refreshProgressProviders();
    // The theme is set through its notifier (no flash back to the old one);
    // a file without a theme leaves the current one alone.
    final theme = plan.snapshot.settings.themeMode;
    if (theme != null) {
      await _ref
          .read(themeModeProvider.notifier)
          .set(ThemeModeSetting.parse(theme));
    }
  }

  /// Makes what cached progress read it again. Everything backed by a live
  /// database query (attempts, cards, mock counts)
  /// refreshes by itself when the import writes its tables; invalidating those
  /// as well would be redundant, and for a provider paused under another route
  /// it makes Riverpod re-run it in the middle of the next build of Inicio
  /// ("setState() called during build"). Only the history, a one-shot read
  /// that depends on the count (which may not change), is invalidated.
  void refreshProgressProviders() {
    _ref.invalidate(mockHistoryProvider);
  }
}

final progressTransferProvider = Provider<ProgressTransfer>(
  ProgressTransfer.new,
);
