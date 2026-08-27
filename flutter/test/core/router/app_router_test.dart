import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/core/app_state.dart';
import 'package:bayaan/core/router/app_router.dart';
import 'package:bayaan/core/router/app_routes.dart';
import 'package:bayaan/features/onboarding/onboarding_flow_screen.dart';
import 'package:bayaan/features/home/home_screen.dart';
import 'package:bayaan/features/learn/roadmap_screen.dart';
import 'package:bayaan/features/quiz/quiz_home_screen.dart';
import 'package:bayaan/features/splash/splash_screen.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:bayaan/services/quran_text.dart';
import 'package:bayaan/shared/widgets/app_bottom_nav.dart';

/// Stands in for a signed-in session without reaching for Supabase.
class _SignedInAuth extends AuthController {
  @override
  AuthUiState get state => const LoggedIn();

  // No Supabase client is wired up in tests, so report a session with no token
  // and let the screens take their signed-out-of-the-backend path.
  @override
  String? get accessToken => null;

  @override
  String? get email => null;
}

/// A state that has cleared every redirect gate, so tests can drive the
/// post-auth routes directly.
AppState signedInState() => AppState(auth: _SignedInAuth())
  ..booting = false
  ..onboarded = true;

/// Pumps a router built from [state] far enough for the redirect chain to
/// resolve, without settling — several screens run endless animations.
Future<void> pumpRouter(
  WidgetTester tester,
  AppState state, {
  String? at,
}) async {
  final router = createRouter(state, initialLocation: at);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  await tester.pump();
}

void main() {
  // The surah list is empty until the bundled Quran assets are parsed.
  setUpAll(QuranText.ensureLoaded);

  testWidgets('a booted state that has not onboarded lands on onboarding', (
    tester,
  ) async {
    final state = AppState()
      ..booting = false
      ..onboarded = false;
    addTearDown(state.dispose);

    await pumpRouter(tester, state);

    expect(find.byType(OnboardingFlowScreen), findsOneWidget);
  });

  testWidgets('the quiz session route falls back to quiz home without extra', (
    tester,
  ) async {
    final state = signedInState();
    addTearDown(state.dispose);

    await pumpRouter(tester, state, at: AppRoutes.quizSession);

    expect(find.byType(QuizHomeScreen), findsOneWidget);
  });

  testWidgets('the quiz result route falls back to quiz home without extra', (
    tester,
  ) async {
    final state = signedInState();
    addTearDown(state.dispose);

    await pumpRouter(tester, state, at: AppRoutes.quizResult);

    expect(find.byType(QuizHomeScreen), findsOneWidget);
  });

  testWidgets(
    'the lesson result route falls back to the roadmap without extra',
    (tester) async {
      final state = signedInState();
      addTearDown(state.dispose);

      await pumpRouter(tester, state, at: AppRoutes.lessonResultPath('l1'));

      expect(find.byType(RoadmapScreen), findsOneWidget);
    },
  );

  testWidgets('a recitation route with a non-numeric sura falls back to home', (
    tester,
  ) async {
    final state = signedInState();
    addTearDown(state.dispose);

    await pumpRouter(tester, state, at: '/recite/abc/1');

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a tab keeps its scroll position across a tab switch', (
    tester,
  ) async {
    final state = signedInState();
    addTearDown(state.dispose);

    await pumpRouter(tester, state, at: AppRoutes.surahs);
    await tester.pump(const Duration(seconds: 1));

    double offset() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
    final scrolled = offset();
    expect(scrolled, greaterThan(0));

    Future<void> tapTab(String label) async {
      await tester.tap(
        find
            .descendant(
              of: find.byType(AppBottomNav),
              matching: find.text(label),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tapTab('Stats');
    await tapTab('Surahs');
    await tester.pump(const Duration(seconds: 1));

    expect(offset(), scrolled);
  });

  testWidgets('a boot asset failure holds the user on splash', (tester) async {
    final state = signedInState()..assetError = true;
    addTearDown(state.dispose);

    await pumpRouter(tester, state, at: AppRoutes.home);

    await tester.pump(const Duration(milliseconds: 1700));

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('an unmatched location shows a recoverable not-found screen', (
    tester,
  ) async {
    final state = signedInState();
    addTearDown(state.dispose);

    await pumpRouter(tester, state, at: '/no-such-page');

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go home'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('drill-down screens do not carry the bottom tab bar', (
    tester,
  ) async {
    for (final route in [
      '/recite/1/1/analysis',
      '/recite/1/1/compare',
      AppRoutes.learn,
      AppRoutes.ayahSelection,
    ]) {
      final state = signedInState();
      await pumpRouter(tester, state, at: route);
      expect(
        find.byType(AppBottomNav),
        findsNothing,
        reason: '$route is a drill-down, not a tab',
      );
      state.dispose();
    }
  });

  testWidgets('the four tab screens keep the bottom tab bar', (tester) async {
    for (final route in [
      AppRoutes.home,
      AppRoutes.surahs,
      AppRoutes.stats,
      AppRoutes.settings,
    ]) {
      final state = signedInState();
      await pumpRouter(tester, state, at: route);
      expect(find.byType(AppBottomNav), findsOneWidget, reason: route);
      // The shell keeps every branch alive, so let their staggered entrance
      // timers drain before the tree is torn down.
      await tester.pump(const Duration(seconds: 2));
      state.dispose();
    }
  });
}
