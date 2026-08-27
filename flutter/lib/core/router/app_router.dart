import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ayah/ayah_selection_screen.dart';
import '../../features/ayah/models/ayah.dart';
import '../../features/auth/email_sign_in_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/learn/lesson_controller.dart';
import '../../features/learn/lesson_result_screen.dart';
import '../../features/learn/lesson_screen.dart';
import '../../features/learn/placement_screen.dart';
import '../../features/learn/roadmap_screen.dart';
import '../../features/onboarding/onboarding_flow_screen.dart';
import '../../features/quiz/models/quiz_question.dart';
import '../../features/quiz/quiz_home_screen.dart';
import '../../features/quiz/quiz_result_screen.dart';
import '../../features/quiz/quiz_session_screen.dart';
import '../../features/recitation/ai_analysis_screen.dart';
import '../../features/recitation/celebration_screen.dart';
import '../../features/audio_compare/audio_compare_screen.dart';
import '../../models/models.dart';
import '../../services/quran_text.dart';
import '../../features/recitation/recording_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/surah/surah_selection_screen.dart';
import '../app_state.dart';
import '../../services/auth_controller.dart';
import '../../shared/widgets/app_bottom_nav.dart';
import 'app_routes.dart';

/// Data passed to the ayah-selection screen (surah name + its ayahs).
class AyahSelectionArgs {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final List<Ayah> ayahs;
  final int initialPage;

  const AyahSelectionArgs({
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.surahNameArabic,
    this.ayahs = const [],
    this.initialPage = 1,
  });
}

/// Data passed to the quiz session screen (category + its question set).
class QuizSessionArgs {
  final QuizCategory category;
  final List<QuizQuestion> questions;

  const QuizSessionArgs({required this.category, required this.questions});
}

/// Data passed to the quiz result screen (final score + streak + the set).
class QuizResultArgs {
  final QuizCategory category;
  final int score;
  final int bestStreak;
  final List<QuizQuestion> questions;

  const QuizResultArgs({
    required this.category,
    required this.score,
    required this.bestStreak,
    required this.questions,
  });
}

/// Holds the four tab branches in a PageView so they can be swiped between,
/// with each branch kept alive to preserve its navigator, scroll offsets and
/// filters — a plain PageView would dispose a branch as it scrolls off.
class _TabShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  final List<Widget> branches;

  const _TabShell({required this.shell, required this.branches});

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> {
  late final PageController _controller = PageController(
    initialPage: widget.shell.currentIndex,
  );

  /// The branch the PageView last told the shell to go to. The sync below
  /// compares against this rather than the controller's own page, so a rebuild
  /// arriving while goBranch is still in flight cannot see a stale
  /// currentIndex and animate a swipe back where it came from.
  late int _reported = widget.shell.currentIndex;

  void _onPageChanged(int index) {
    _reported = index;
    widget.shell.goBranch(index);
  }

  @override
  void didUpdateWidget(covariant _TabShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only follow branch changes that came from somewhere else — the bottom
    // bar, or a route change.
    final target = widget.shell.currentIndex;
    if (target == _reported || !_controller.hasClients) return;
    _reported = target;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageView(
      controller: _controller,
      onPageChanged: _onPageChanged,
      children: [
        for (final branch in widget.branches) _KeepAlive(child: branch),
      ],
    ),
    bottomNavigationBar: AppBottomNav(
      currentIndex: widget.shell.currentIndex,
      // Re-tapping the active tab pops it back to its root.
      onTap: (i) => widget.shell.goBranch(
        i,
        initialLocation: i == widget.shell.currentIndex,
      ),
    ),
  );
}

/// Keeps a branch mounted while it is off-screen in the PageView.
class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Shown for any location that matches no route, instead of go_router's
/// unstyled default.
class _NotFound extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Page not found'),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Go home'),
          ),
        ],
      ),
    ),
  );
}

/// The four `/recite/:sura/:aya` routes parse both params as ints. A hand-typed
/// or malformed URL would blow up in the builder, so bounce it home instead.
String? _requireVerseParams(GoRouterState state) {
  final sura = int.tryParse(state.pathParameters['sura'] ?? '');
  final aya = int.tryParse(state.pathParameters['aya'] ?? '');
  return sura == null || aya == null ? AppRoutes.home : null;
}

QuizHomeScreen _quizHome(BuildContext context) => QuizHomeScreen(
  onStart: (category, questions) => context.push(
    AppRoutes.quizSession,
    extra: QuizSessionArgs(category: category, questions: questions),
  ),
);

/// Builds the app router around a given [AppState] so tests can drive
/// redirects with a state they control instead of the process-wide singleton.
GoRouter createRouter(AppState appState, {String? initialLocation}) => GoRouter(
  initialLocation: initialLocation ?? AppRoutes.splash,
  errorBuilder: (context, state) => _NotFound(),
  refreshListenable: appState,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    // A failed asset load leaves QuranText empty, which would break every
    // reading screen downstream — hold on splash and let the user retry.
    if (appState.booting || appState.assetError) {
      return loc == AppRoutes.splash ? null : AppRoutes.splash;
    }
    if (!appState.onboarded) {
      return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
    }
    final loggedIn = appState.auth.state is LoggedIn;
    const authScreens = {AppRoutes.signIn, AppRoutes.emailSignIn};
    if (!loggedIn) {
      return authScreens.contains(loc) ? null : AppRoutes.signIn;
    }
    final preAuthScreens = {
      AppRoutes.splash,
      AppRoutes.onboarding,
      ...authScreens,
    };
    if (preAuthScreens.contains(loc)) return AppRoutes.home;
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => SplashScreen(state: appState),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingFlowScreen(),
    ),
    GoRoute(
      path: AppRoutes.signIn,
      builder: (context, state) => SignInScreen(auth: appState.auth),
    ),
    GoRoute(
      path: AppRoutes.emailSignIn,
      builder: (context, state) => EmailSignInScreen(auth: appState.auth),
    ),
    StatefulShellRoute(
      builder: (context, state, shell) => shell,
      navigatorContainerBuilder: (context, shell, children) =>
          _TabShell(shell: shell, branches: children),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => HomeScreen(auth: appState.auth),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.surahs,
              builder: (context, state) => const SurahSelectionScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.stats,
              builder: (context, state) => StatsScreen(auth: appState.auth),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => SettingsScreen(auth: appState.auth),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.ayahSelection,
      builder: (context, state) {
        final args = state.extra as AyahSelectionArgs?;
        final sura = args?.surahNumber ?? 1;
        return AyahSelectionScreen(
          surahNumber: sura,
          surahNameEnglish: args?.surahNameEnglish ?? 'Al-Fatihah',
          surahNameArabic: args?.surahNameArabic ?? 'سُورَةُ الفَاتِحَة',
          ayahs: args?.ayahs ?? const [],
          initialPage: args?.initialPage ?? (QuranText.pageFor(sura, 1) ?? 1),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.recording,
      redirect: (context, state) => _requireVerseParams(state),
      builder: (context, state) => RecordingScreen(
        controller: appState.recitation,
        auth: appState.auth,
        sura: int.parse(state.pathParameters['sura']!),
        aya: int.parse(state.pathParameters['aya']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.aiAnalysis,
      redirect: (context, state) => _requireVerseParams(state),
      builder: (context, state) => AiAnalysisScreen(
        controller: appState.recitation,
        sura: int.parse(state.pathParameters['sura']!),
        aya: int.parse(state.pathParameters['aya']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.celebration,
      redirect: (context, state) => _requireVerseParams(state),
      builder: (context, state) => CelebrationScreen(
        controller: appState.recitation,
        sura: int.parse(state.pathParameters['sura']!),
        aya: int.parse(state.pathParameters['aya']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.audioCompare,
      redirect: (context, state) => _requireVerseParams(state),
      builder: (context, state) {
        final sura = int.parse(state.pathParameters['sura']!);
        final aya = int.parse(state.pathParameters['aya']!);
        final st = appState.recitation.stateFor(sura, aya);
        final result = st is ResultState ? st : null;
        return AudioCompareScreen(
          verse: result?.verse ?? QuranText.verseFor(sura, aya),
          mistakes: result?.mistakes ?? const [],
        );
      },
    ),
    GoRoute(
      path: AppRoutes.quiz,
      builder: (context, state) => _quizHome(context),
    ),
    GoRoute(
      path: AppRoutes.quizSession,
      builder: (context, state) {
        // `extra` does not survive a reload or a cold deep link, so fall back
        // to the quiz picker instead of crashing on a null cast.
        final args = state.extra as QuizSessionArgs?;
        if (args == null) return _quizHome(context);
        return QuizSessionScreen(
          questions: args.questions,
          onComplete: (score, streak) => context.pushReplacement(
            AppRoutes.quizResult,
            extra: QuizResultArgs(
              category: args.category,
              score: score,
              bestStreak: streak,
              questions: args.questions,
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.quizResult,
      builder: (context, state) {
        final args = state.extra as QuizResultArgs?;
        if (args == null) return _quizHome(context);
        return QuizResultScreen(
          score: args.score,
          total: args.questions.length,
          bestStreak: args.bestStreak,
          onPlayAgain: () => context.pushReplacement(
            AppRoutes.quizSession,
            extra: QuizSessionArgs(
              category: args.category,
              questions: args.questions,
            ),
          ),
          onDone: () => context.go(AppRoutes.home),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.learn,
      builder: (context, state) => RoadmapScreen(auth: appState.auth),
    ),
    GoRoute(
      path: AppRoutes.placement,
      builder: (context, state) => PlacementScreen(auth: appState.auth),
    ),
    GoRoute(
      path: AppRoutes.lesson,
      builder: (context, state) => LessonScreen(
        lessonId: state.pathParameters['lessonId']!,
        auth: appState.auth,
      ),
    ),
    GoRoute(
      path: AppRoutes.lessonResult,
      builder: (context, state) {
        final controller = state.extra as LessonController?;
        if (controller == null) return RoadmapScreen(auth: appState.auth);
        return LessonResultScreen(controller: controller, auth: appState.auth);
      },
    ),
  ],
);

final appRouter = createRouter(appState);
