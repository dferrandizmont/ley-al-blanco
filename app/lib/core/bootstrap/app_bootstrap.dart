import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/content/data/content_importer.dart';
import '../../features/content/data/content_manifest.dart';
import '../providers.dart';

/// What the bootstrap produced: the bank's manifest (edition, source, date,
/// for Ajustes) and what the import did this launch.
class BootstrapResult {
  const BootstrapResult({required this.manifest, required this.import});

  final ContentManifest manifest;
  final ImportResult import;
}

/// Opens the database and imports the bundled bank once per edition/checksum.
/// A failure is shown by BootstrapGate with an option to retry.
final bootstrapProvider = FutureProvider<BootstrapResult>((ref) async {
  final result = await ref.watch(contentImporterProvider).importIfNeeded();
  return BootstrapResult(manifest: result.manifest, import: result);
});
