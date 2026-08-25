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
import '../../features/recitation/ai_analysis_screen.dart';
import '../../features/recitation/celebration_screen.dart';
import '../../features/recitation/recording_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/surah/surah_selection_screen.dart';
import '../app_state.dart';
import '../../services/auth_controller.dart';
import 'app_routes.dart';

/// Data passed to the ayah-selection screen (surah name + its ayahs).
class AyahSelectionArgs {
  final int surahNumber;
  final String surahNameEnglish;
  final String surahNameArabic;
  final List<Ayah> ayahs;

  const AyahSelectionArgs({
    required this.surahNumber,
    required this.surahNameEnglish,
    required this.surahNameArabic,
    required this.ayahs,
  });
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: appState,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    if (appState.booting) {
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
      builder: (context, state) => const SplashScreen(),
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
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => HomeScreen(auth: appState.auth),
    ),
    GoRoute(
      path: AppRoutes.surahs,
      builder: (context, state) => const SurahSelectionScreen(),
    ),
    GoRoute(
      path: AppRoutes.ayahSelection,
      builder: (context, state) {
        final args = state.extra as AyahSelectionArgs?;
        return AyahSelectionScreen(
          surahNumber: args?.surahNumber ?? 1,
          surahNameEnglish: args?.surahNameEnglish ?? 'Al-Fatihah',
          surahNameArabic: args?.surahNameArabic ?? 'سُورَةُ الفَاتِحَة',
          ayahs: args?.ayahs ?? const [],
        );
      },
    ),
    GoRoute(
      path: AppRoutes.recording,
      builder: (context, state) => RecordingScreen(
        controller: appState.recitation,
        auth: appState.auth,
        sura: int.parse(state.pathParameters['sura']!),
        aya: int.parse(state.pathParameters['aya']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.aiAnalysis,
      builder: (context, state) => AiAnalysisScreen(
        controller: appState.recitation,
        sura: int.parse(state.pathParameters['sura']!),
        aya: int.parse(state.pathParameters['aya']!),
      ),
    ),
    GoRoute(
      path: AppRoutes.celebration,
      builder: (context, state) => CelebrationScreen(
        controller: appState.recitation,
        sura: int.parse(state.pathParameters['sura']!),
        aya: int.parse(state.pathParameters['aya']!),
      ),
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
      builder: (context, state) => LessonResultScreen(
        controller: state.extra as LessonController,
        auth: appState.auth,
      ),
    ),
    GoRoute(
      path: AppRoutes.stats,
      builder: (context, state) => const StatsScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => SettingsScreen(auth: appState.auth),
    ),
  ],
);
