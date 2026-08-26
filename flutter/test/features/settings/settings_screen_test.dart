import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/features/settings/settings_screen.dart';
import 'package:bayaan/services/auth_controller.dart';

class _MockAuthController extends AuthController {
  bool signedOut = false;

  @override
  String? get email => 'testuser@example.com';

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders profile card, settings sections, and sign out button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockAuth = _MockAuthController();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(auth: mockAuth),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Profile
      expect(find.text('Settings'), findsNWidgets(2)); // Title and bottom nav
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('testuser@example.com'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);

      // Section headers
      expect(find.text('Recitation & Audio'), findsOneWidget);
      expect(find.text('Mushaf & Display'), findsOneWidget);
      expect(find.text('Practice & Reminders'), findsOneWidget);
      expect(find.text('About & Support'), findsOneWidget);

      // Interactive widgets
      expect(find.text('Reference Reciter'), findsOneWidget);
      expect(find.text('AI Tajweed Sensitivity'), findsOneWidget);
      expect(find.text('Tajweed color highlights'), findsOneWidget);

      // Tap Sign Out opens confirmation dialog
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to sign out of Bayaan?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel closes dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to sign out of Bayaan?'), findsNothing);
      expect(mockAuth.signedOut, isFalse);

      // Tap Sign Out and confirm
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(mockAuth.signedOut, isTrue);
    });
  });
}
