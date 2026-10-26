import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../domain/progress_snapshot.dart';

/// What the user chose when asked for a file to import.
sealed class PickedProgressFile {
  const PickedProgressFile();
}

/// The user closed the picker without choosing.
class PickCancelled extends PickedProgressFile {
  const PickCancelled();
}

/// The chosen file is bigger than [kMaxProgressFileBytes]; it was not read
/// (past the limit).
class PickTooLarge extends PickedProgressFile {
  const PickTooLarge();
}

/// The bytes of the chosen file (at most [kMaxProgressFileBytes]).
class PickedBytes extends PickedProgressFile {
  const PickedBytes(this.bytes);

  final Uint8List bytes;
}

/// Where the progress file goes to and comes from: the system's own file
/// dialogs. The app asks for no storage permission: the user picks the place
/// (Android Storage Access Framework, iOS document picker) and the system
/// hands over just that one file.
///
/// This is the test seam: widget and integration tests replace it, so the
/// native picker (which cannot be driven from Dart) is never opened.
abstract class ProgressFileStore {
  /// Asks where to save [bytes] as [fileName]. True when it was saved, false
  /// when the user cancelled. Throws if saving failed.
  Future<bool> save({required String fileName, required Uint8List bytes});

  /// Asks the user for a file and returns its bytes.
  Future<PickedProgressFile> pick();
}

/// The real store, over `file_picker` (Android: `ACTION_CREATE_DOCUMENT` /
/// `ACTION_OPEN_DOCUMENT` through the Storage Access Framework; iOS:
/// `UIDocumentPickerViewController` for exporting and opening).
///
/// Temporary copies the plugin leaves behind are removed differently per
/// platform: on Android `clearTemporaryFiles` only empties the plugin's own
/// cache folder, so it is safe; on iOS it deletes **everything in the app's
/// `tmp/`** (other SDKs keep files there), so it is never called: only the
/// copy of the file that was just imported is deleted, by its own path. The
/// file the plugin writes to export on iOS has no path we can reach and is
/// left to the system, which empties `tmp/` by itself.
class SystemProgressFileStore implements ProgressFileStore {
  const SystemProgressFileStore();

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/json',
      );
      return saved != null;
    } finally {
      await _cleanUp(null);
    }
  }

  @override
  Future<PickedProgressFile> pick() async {
    PlatformFile? file;
    try {
      // Any type: other apps often label a .json as octet-stream and the
      // picker would grey it out. The content is validated strictly anyway.
      file = await FilePicker.pickFile();
      if (file == null) return const PickCancelled();
      final size = file.lengthSync() ?? await file.length();
      if (size != null && size > kMaxProgressFileBytes) {
        return const PickTooLarge();
      }
      // Read as a stream and stop at the limit: the size above can be
      // unknown or wrong.
      final out = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        out.add(chunk);
        if (out.length > kMaxProgressFileBytes) return const PickTooLarge();
      }
      return PickedBytes(out.takeBytes());
    } finally {
      await _cleanUp(file);
    }
  }

  /// Best effort; never throws. [picked] is the file just imported, if any.
  Future<void> _cleanUp(PlatformFile? picked) async {
    try {
      if (Platform.isAndroid) {
        await FilePicker.clearTemporaryFiles();
      } else if (Platform.isIOS) {
        await _deleteTemporaryCopy(picked?.path);
      }
    } on Object {
      // The system cleans its temporary folder anyway.
    }
  }

  /// Deletes [path] only when it is a file inside the temporary folder (the
  /// plugin's copy), never a file in place somewhere the user keeps it.
  Future<void> _deleteTemporaryCopy(String? path) async {
    if (path == null) return;
    final tmp = Directory.systemTemp.resolveSymbolicLinksSync();
    final file = File(path);
    if (!file.existsSync()) return;
    final real = file.resolveSymbolicLinksSync();
    if (real.startsWith('$tmp${Platform.pathSeparator}')) {
      await file.delete();
    }
  }
}
