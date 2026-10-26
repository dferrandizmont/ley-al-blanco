import 'dart:convert';
import 'dart:typed_data';

import 'package:apto_armas/features/progress_transfer/application/progress_transfer_providers.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_codec_runner.dart';
import 'package:apto_armas/features/progress_transfer/data/progress_file_store.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_codec.dart';
import 'package:apto_armas/features/progress_transfer/domain/progress_snapshot.dart';
import 'package:apto_armas/features/quiz/domain/attempt.dart';
import 'package:apto_armas/features/settings/application/settings_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'db_support.dart';

/// Records the links instead of opening them (the real launcher would reach
/// the platform). [result] is what `open` answers.
class FakeUrlLauncher implements UrlLauncher {
  FakeUrlLauncher({this.result = true});

  final bool result;
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}

/// The system file dialogs of «Tus datos», replaced: the native picker cannot
/// be driven from Dart. [pickResult] is what the user "chooses"; [saveResult]
/// whether they "save" (false = cancel); [saveError] makes saving fail.
class FakeProgressFileStore implements ProgressFileStore {
  FakeProgressFileStore({
    this.pickResult = const PickCancelled(),
    this.saveResult = true,
    this.saveError,
    this.pickError,
  });

  PickedProgressFile pickResult;
  bool saveResult;
  Object? saveError;
  Object? pickError;

  var pickCalls = 0;
  final saved = <({String fileName, Uint8List bytes})>[];

  @override
  Future<bool> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    saved.add((fileName: fileName, bytes: bytes));
    return saveResult;
  }

  @override
  Future<PickedProgressFile> pick() async {
    pickCalls++;
    final error = pickError;
    if (error != null) throw error;
    return pickResult;
  }
}

/// A valid progress file with [attempts] answers (every third one wrong), one
/// finished mock and [srs] review cards, on real bank ids; [edit] changes the
/// JSON before it is written.
Uint8List progressFileBytes({
  int attempts = 3,
  int srs = 2,
  String theme = 'dark',
  DateTime? exportedAt,
  void Function(Map<String, dynamic> json)? edit,
}) {
  final bank = realQuestionsJson();
  final ids = [for (final q in bank) q['id'] as String];
  int answerOf(int i) => bank[i]['answer'] as int;
  final snapshot = ProgressSnapshot(
    edition: 'GC-2020-11',
    exportedAt: exportedAt ?? DateTime(2026, 10, 12, 12),
    appVersion: '0.5.0',
    attempts: [
      for (var i = 0; i < attempts; i++)
        Attempt(
          questionId: ids[i],
          mode: AttemptMode.practice,
          // The flag is recomputed from the bank on import: keep it true.
          selected: i % 3 != 2 ? answerOf(i) : (answerOf(i) + 1) % 3,
          correct: i % 3 != 2,
          answeredAt: DateTime(2026, 10, 10, 9, i),
        ),
    ],
    srs: [
      for (var i = 0; i < srs; i++)
        SrsEntry(
          questionId: ids[i],
          box: 1 + i % 5,
          dueAt: DateTime(2026, 10, 16, 10),
          reps: 1,
          lapses: 0,
          lastAnsweredAt: DateTime(2026, 10, 10, 9),
        ),
    ],
    mocks: [
      MockEntry(
        id: 1,
        startedAt: DateTime(2026, 10, 11, 18),
        finishedAt: DateTime(2026, 10, 11, 18, 30),
        // A mock is always the exam's size (20), whatever its questions.
        questionIds: ids.take(20).toList(),
        answers: [answerOf(0), for (var i = 1; i < 20; i++) null],
        correctCount: 1,
        passed: false,
        timed: false,
        passMark: 16,
      ),
    ],
    settings: ProgressSettings(themeMode: theme),
  );
  final bytes = ProgressCodec.encode(snapshot);
  if (edit == null) return bytes;
  final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  edit(json);
  return Uint8List.fromList(utf8.encode(jsonEncode(json)));
}

/// Both outside links set.
const kTestLinks = SettingsLinks(
  supportEmail: 'soporte@ejemplo.es',
  privacyUrl: 'https://ejemplo.es/privacidad',
);

/// Overrides of everything Ajustes reads from the platform: the app version,
/// the platform name and system version, the launcher and the two `--dart-define` links.
List<Override> settingsOverrides({
  required FakeUrlLauncher launcher,
  SettingsLinks links = kTestLinks,
  ProgressFileStore? fileStore,
  ProgressCodecRunner codecRunner = const InlineProgressCodecRunner(),
}) => [
  urlLauncherProvider.overrideWithValue(launcher),
  // A real isolate cannot finish under the fake clock of `testWidgets`.
  progressCodecRunnerProvider.overrideWithValue(codecRunner),
  if (fileStore != null) progressFileStoreProvider.overrideWithValue(fileStore),
  settingsLinksProvider.overrideWithValue(links),
  appInfoProvider.overrideWith(
    (ref) async => const AppInfo(version: '1.2.3', buildNumber: '45'),
  ),
  platformNameProvider.overrideWithValue('Android'),
  systemLabelProvider.overrideWith((ref) async => 'Android 16'),
];
