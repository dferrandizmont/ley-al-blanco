import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quiz/domain/practice_source.dart';
import '../../quiz/presentation/practice_screen.dart';
import '../application/daily_providers.dart';

/// `/pregunta-del-dia`: today's question on the practice screen (one question,
/// its explanation, "Terminar"). Answering it advances the streak.
///
/// Waits for today's pick, then hands it to [PracticeScreen]; the pick is kept
/// for the life of the screen, so the question does not change under the user
/// when the status refreshes after the answer (or at midnight).
class DailyQuestionScreen extends ConsumerStatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  ConsumerState<DailyQuestionScreen> createState() =>
      _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends ConsumerState<DailyQuestionScreen> {
  String? _questionId;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(dailyStatusProvider);
    _questionId ??= status.value?.question?.id;
    final id = _questionId;
    if (id != null) {
      return PracticeScreen(source: DailyQuestionPractice(id));
    }
    if (status.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // No question to offer (an empty bank): the practice screen's own empty
    // state, with its way back.
    return const PracticeScreen(source: DailyQuestionPractice(''));
  }
}
