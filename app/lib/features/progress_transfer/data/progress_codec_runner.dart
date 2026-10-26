import 'dart:isolate';
import 'dart:typed_data';

import '../../mock/domain/mock_config.dart';
import '../domain/progress_codec.dart';
import '../domain/progress_snapshot.dart';

/// Where [ProgressCodec] runs. Parsing or writing a big progress file (up to
/// 10 MB) takes long enough to drop frames, so the app does it on another
/// isolate; tests that cannot wait for a real isolate use the inline one.
abstract class ProgressCodecRunner {
  const ProgressCodecRunner();

  /// [ProgressCodec.parse] ([mockSize]: the exam's size); a
  /// [ProgressImportException] thrown there surfaces here unchanged.
  Future<ProgressSnapshot> parse(
    Uint8List bytes, {
    required DateTime now,
    int mockSize = MockConfig.defaultSize,
  });

  /// [ProgressCodec.encode].
  Future<Uint8List> encode(ProgressSnapshot snapshot);
}

/// Runs the codec on a short-lived isolate (`Isolate.run`).
class IsolateProgressCodecRunner extends ProgressCodecRunner {
  const IsolateProgressCodecRunner();

  @override
  Future<ProgressSnapshot> parse(
    Uint8List bytes, {
    required DateTime now,
    int mockSize = MockConfig.defaultSize,
  }) => Isolate.run(
    () => ProgressCodec.parse(bytes, now: now, mockSize: mockSize),
  );

  @override
  Future<Uint8List> encode(ProgressSnapshot snapshot) =>
      Isolate.run(() => ProgressCodec.encode(snapshot));
}

/// Runs the codec right here, on the calling isolate.
class InlineProgressCodecRunner extends ProgressCodecRunner {
  const InlineProgressCodecRunner();

  @override
  Future<ProgressSnapshot> parse(
    Uint8List bytes, {
    required DateTime now,
    int mockSize = MockConfig.defaultSize,
  }) => Future.sync(
    () => ProgressCodec.parse(bytes, now: now, mockSize: mockSize),
  );

  @override
  Future<Uint8List> encode(ProgressSnapshot snapshot) =>
      Future.sync(() => ProgressCodec.encode(snapshot));
}
