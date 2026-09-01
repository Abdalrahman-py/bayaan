import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/features/settings/settings_screen.dart';
import 'package:bayaan/services/accounts_manager.dart';
import 'package:bayaan/services/app_settings.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:bayaan/services/reciter_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthController extends AuthController {
  bool signedOut = false;

  @override
  String? get email => 'testuser@example.com';

  @override
  String? get displayName => 'Test User';

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  group('SettingsScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.load();
      await AccountsManager.instance.load();
    });

    Future<void> pumpSettings(WidgetTester tester, AuthController auth) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(home: SettingsScreen(auth: auth)));
      await tester.pumpAndSettle();
    }

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
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('testuser@example.com'), findsOneWidget);

      // Section headers
      expect(find.text('RECITATION & COACHING'), findsOneWidget);
      expect(find.text('PRACTICE & REMINDERS'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('ABOUT & LEGAL'), findsOneWidget);

      // Interactive rows
      expect(find.text('Reference Reciter'), findsOneWidget);
      expect(find.text('Tajweed Sensitivity'), findsOneWidget);
      expect(find.text('Madd Length'), findsOneWidget);
      expect(find.text('Show Transliteration'), findsOneWidget);
      expect(find.text('App Language'), findsOneWidget);
      expect(find.text('About Bayaan'), findsOneWidget);

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

    testWidgets('each control writes through to AppSettings and persists', (
      tester,
    ) async {
      await pumpSettings(tester, _MockAuthController());
      final settings = AppSettings.instance;

      // Madd Length picker
      await tester.tap(find.text('Madd Length'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MaddStyle.ishbaa.name).last);
      await tester.pumpAndSettle();
      expect(settings.maddStyle, MaddStyle.ishbaa);

      // Switches
      await tester.tap(find.text('Auto-play Reference Audio'));
      await tester.pumpAndSettle();
      expect(settings.autoPlayReference, isFalse);

      await tester.tap(find.text('Show Transliteration'));
      await tester.pumpAndSettle();
      expect(settings.showTranslation, isFalse);

      // Reciter picker
      await tester.tap(find.text('Reference Reciter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Reciter.alafasy.name).last);
      await tester.pumpAndSettle();
      expect(settings.reciter, Reciter.alafasy);

      // Language picker
      await tester.tap(find.text('App Language'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية (Arabic)').last);
      await tester.pumpAndSettle();
      expect(settings.appLanguage, 'ar');

      // Reloading from the store returns the same choices
      await settings.load();
      expect(settings.maddStyle, MaddStyle.ishbaa);
      expect(settings.autoPlayReference, isFalse);
      expect(settings.showTranslation, isFalse);
      expect(settings.reciter, Reciter.alafasy);
      expect(settings.appLanguage, 'ar');
    });

    testWidgets('opens on whatever was saved last', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reference_reciter': Reciter.abdulBasit.id,
        'madd_style': MaddStyle.qasr.id,
        'daily_goal_minutes': 30,
        'app_language': 'ar',
      });
      await AppSettings.instance.load();

      await pumpSettings(tester, _MockAuthController());

      expect(find.text(Reciter.abdulBasit.name), findsOneWidget);
      expect(find.textContaining(MaddStyle.qasr.summary), findsOneWidget);
      expect(find.text('30 min/day'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
    });
  });
}

