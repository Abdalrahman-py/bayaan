import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/features/stats/stats_screen.dart';
import 'package:bayaan/services/auth_controller.dart';

/// No Supabase client is wired up in tests, so report a session with no token
/// and let the screen take its signed-out-of-the-backend path.
class _NoTokenAuth extends AuthController {
  @override
  AuthUiState get state => const LoggedIn();

  @override
  String? get accessToken => null;
}

void main() {
  group('StatsScreen', () {
    testWidgets('renders the header and asks for sign-in without a token', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: StatsScreen(auth: _NoTokenAuth())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Progress'), findsOneWidget);
      expect(find.text('وَقُل رَّبِّ زِدْنِي عِلْمًا'), findsOneWidget);
      expect(find.text('Sign in to see your progress.'), findsOneWidget);
    });

    testWidgets('shows no numbers it did not get from the backend', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: StatsScreen(auth: _NoTokenAuth())),
      );
      await tester.pumpAndSettle();

      // Guards the regression this screen was built to fix: the old version
      // hard-coded these, so they rendered for a user with no data at all.
      for (final placeholder in ['7 Days', '48', '94%', '650', '4h 5m total']) {
        expect(find.text(placeholder), findsNothing);
      }
      expect(find.text('Milestones & Badges'), findsNothing);
    });
  });
}
