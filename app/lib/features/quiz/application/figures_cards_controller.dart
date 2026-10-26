import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../content/application/content_providers.dart';
import '../../content/domain/question.dart';

/// One round, held only in memory. A repeated card stays in the queue until
/// marked known, but can never count as known on the first try afterwards.
@immutable
class FiguresCardsState {
  FiguresCardsState({
    required List<Question> pending,
    required this.total,
    Set<String> seen = const {},
    List<Question> reviewed = const [],
    this.knownFirstTry = 0,
    this.revealed = false,
  }) : pending = List.unmodifiable(pending),
       seen = Set.unmodifiable(seen),
       reviewed = List.unmodifiable(reviewed);

  final List<Question> pending;
  final int total;
  final Set<String> seen;
  final List<Question> reviewed;
  final int knownFirstTry;
  final bool revealed;

  bool get isEmpty => total == 0;
  bool get finished => !isEmpty && pending.isEmpty;
  Question get current => pending.first;

  /// Progress counts cards removed from the deck; repeating one does not
  /// advance the bar or make the denominator grow.
  int get completed => total - pending.length;
  int get position => completed + 1;
}

/// No study service, attempts or SRS writes: leaving disposes the whole round.
class FiguresCardsController extends AsyncNotifier<FiguresCardsState> {
  @override
  Future<FiguresCardsState> build() async {
    final bank = await ref.watch(questionsProvider.future);
    final deck = [
      for (final q in bank)
        if (q.isFigures) q,
    ]..shuffle(ref.read(randomProvider));
    return FiguresCardsState(pending: deck, total: deck.length);
  }

  void reveal() {
    final value = state.value;
    if (value == null || value.pending.isEmpty || value.revealed) return;
    state = AsyncData(
      FiguresCardsState(
        pending: value.pending,
        total: value.total,
        seen: value.seen,
        reviewed: value.reviewed,
        knownFirstTry: value.knownFirstTry,
        revealed: true,
      ),
    );
  }

  void answer({required bool known}) {
    final value = state.value;
    if (value == null || !value.revealed || value.pending.isEmpty) return;
    final question = value.current;
    final firstTry = !value.seen.contains(question.id);
    state = AsyncData(
      FiguresCardsState(
        pending: [...value.pending.skip(1), if (!known) question],
        total: value.total,
        seen: {...value.seen, question.id},
        reviewed: [...value.reviewed, if (!known && firstTry) question],
        knownFirstTry: value.knownFirstTry + (known && firstTry ? 1 : 0),
      ),
    );
  }

  void restartReviewed() {
    final value = state.value;
    if (value == null || !value.finished || value.reviewed.isEmpty) return;
    final deck = [...value.reviewed]..shuffle(ref.read(randomProvider));
    state = AsyncData(FiguresCardsState(pending: deck, total: deck.length));
  }
}

final figuresCardsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      FiguresCardsController,
      FiguresCardsState
    >(FiguresCardsController.new);
