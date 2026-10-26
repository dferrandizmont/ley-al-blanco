import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/daily/presentation/daily_question_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/mistakes/presentation/mistakes_screen.dart';
import '../features/mock/presentation/mock_intro_screen.dart';
import '../features/mock/presentation/mock_result_screen.dart';
import '../features/mock/presentation/mock_review_screen.dart';
import '../features/mock/presentation/mock_screen.dart';
import '../features/quiz/domain/practice_source.dart';
import '../features/quiz/presentation/figures_cards_screen.dart';
import '../features/quiz/presentation/practice_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/theory/domain/theory.dart';
import '../features/theory/presentation/theory_doc_screen.dart';
import '../features/theory/presentation/theory_list_screen.dart';
import 'l10n/tema_title.dart';

/// Unknown locations (a `content://` or `file://` URI, a custom scheme, a
/// stale deep link...) never render an error page: stay on the last route that
/// matched, or go home when there is none.
void unknownLocationFallback(
  BuildContext context,
  GoRouterState state,
  GoRouter router,
) {
  // The last configuration that matched (not the unknown location that is
  // being rejected, which the information provider already holds).
  final current = router.routerDelegate.currentConfiguration.uri;
  final valid =
      !current.hasScheme &&
      current.path.startsWith('/') &&
      current.toString() != state.uri.toString();
  router.go(valid ? current.toString() : '/');
}

/// A tema number in 1..[kTemaCount], or null.
int? _parseTema(String? raw) {
  final tema = int.tryParse(raw ?? '');
  return tema != null && tema >= 1 && tema <= kTemaCount ? tema : null;
}

/// A question id such as `t3-012`, or null.
String? _parseQuestionId(String? raw) =>
    raw != null && RegExp(r'^t[1-7]-\d{3}$').hasMatch(raw) ? raw : null;

/// A non-negative integer path parameter, or null.
int? _parseId(String? raw) {
  final value = int.tryParse(raw ?? '');
  return value != null && value >= 0 ? value : null;
}

/// Offline routes: every study mode and all seven temas are open.
GoRouter createRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    onException: unknownLocationFallback,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/tema/:n',
        redirect: (context, state) async {
          final tema = _parseTema(state.pathParameters['n']);
          if (tema == null) return '/';
          return null;
        },
        builder: (context, state) => PracticeScreen(
          key: ValueKey(state.uri.toString()),
          source: TemaPractice(_parseTema(state.pathParameters['n'])!),
        ),
      ),
      GoRoute(
        path: '/teoria',
        builder: (context, state) => const TheoryListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) async {
              final id = state.pathParameters['id'] ?? '';
              // The documents without a tema are free for everyone.
              if (kTemalessDocIds.contains(id)) return null;
              final tema = temaOfDocId(id);
              if (tema == null) return '/teoria';
              return null;
            },
            builder: (context, state) => TheoryDocScreen(
              key: ValueKey(state.uri.toString()),
              docId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/repaso',
        builder: (context, state) =>
            const PracticeScreen(source: DailyPractice()),
      ),
      GoRoute(
        path: '/cifras',
        builder: (context, state) =>
            const PracticeScreen(source: FiguresPractice()),
      ),
      GoRoute(
        path: '/cifras/tarjetas',
        builder: (context, state) => const FiguresCardsScreen(),
      ),
      GoRoute(
        path: '/pregunta-del-dia',
        builder: (context, state) => const DailyQuestionScreen(),
      ),
      GoRoute(
        path: '/fallos',
        builder: (context, state) => const MistakesScreen(),
        routes: [
          GoRoute(
            path: 'repasar',
            builder: (context, state) => PracticeScreen(
              key: ValueKey(state.uri.toString()),
              source: MistakesPractice(
                _parseTema(state.uri.queryParameters['tema']),
                _parseQuestionId(state.uri.queryParameters['desde']),
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/simulacro',
        builder: (context, state) => const MockIntroScreen(),
        routes: [
          GoRoute(
            path: ':id',
            redirect: (context, state) async {
              final id = _parseId(state.pathParameters['id']);
              if (id == null) return '/';
              return null;
            },
            builder: (context, state) =>
                MockScreen(mockId: _parseId(state.pathParameters['id'])!),
            routes: [
              GoRoute(
                path: 'resultado',
                builder: (context, state) => MockResultScreen(
                  mockId: _parseId(state.pathParameters['id'])!,
                ),
              ),
              GoRoute(
                path: 'repasar',
                builder: (context, state) => PracticeScreen(
                  key: ValueKey(state.uri.toString()),
                  source: MockMistakesPractice(
                    _parseId(state.pathParameters['id'])!,
                  ),
                ),
              ),
              GoRoute(
                path: 'revision/:index',
                redirect: (context, state) =>
                    _parseId(state.pathParameters['index']) == null
                    ? '/'
                    : null,
                builder: (context, state) => MockReviewScreen(
                  mockId: _parseId(state.pathParameters['id'])!,
                  index: _parseId(state.pathParameters['index'])!,
                  onlyFailed: state.uri.queryParameters['falladas'] == '1',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/buscar',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/ajustes',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter();
  ref.onDispose(router.dispose);
  return router;
});
