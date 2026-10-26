import 'package:flutter/foundation.dart';

/// Debug-only timing of a step (OCR, image preparation, backend request).
///
/// Prints one line `timing step=ocr ms=812 kind=menu` in debug builds and does
/// nothing in release. Only the step name, milliseconds and short non-content
/// labels (a document kind, a count) may be passed: never text, file names or
/// model output.
Future<T> timed<T>(
  String step,
  Future<T> Function() run, {
  Map<String, Object> labels = const {},
  void Function(String line)? sink,
}) async {
  if (!kDebugMode && sink == null) return run();
  final watch = Stopwatch()..start();
  try {
    return await run();
  } finally {
    watch.stop();
    final extra = labels.entries.map((e) => ' ${e.key}=${e.value}').join();
    final line = 'timing step=$step ms=${watch.elapsedMilliseconds}$extra';
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }
}
