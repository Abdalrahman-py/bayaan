import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/features/settings/settings_screen.dart';
import 'package:bayaan/services/app_settings.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:bayaan/services/reciter_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.load();
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
      // The tab bar now lives in the router shell, so only the title is here.
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('testuser@example.com'), findsOneWidget);
      expect(find.text('T'), findsOneWidget);

      // Section headers
      expect(find.text('Recitation & Audio'), findsOneWidget);
      expect(find.text('Mushaf & Display'), findsOneWidget);
      expect(find.text('Practice Goal'), findsOneWidget);
      expect(find.text('About & Support'), findsOneWidget);

      // Interactive widgets
      expect(find.text('Reference Reciter'), findsOneWidget);
      expect(find.text('Madd Length'), findsOneWidget);
      expect(find.text('Show transliteration & translation'), findsOneWidget);

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

      await tester.tap(find.text(MaddStyle.ishbaa.name));
      await tester.pumpAndSettle();
      expect(settings.maddStyle, MaddStyle.ishbaa);
      // The counts under the heading follow the choice.
      expect(find.textContaining(MaddStyle.ishbaa.summary), findsOneWidget);

      await tester.tap(find.text('Auto-play reference audio'));
      await tester.pumpAndSettle();
      expect(settings.autoPlayReference, isFalse);

      await tester.tap(find.text('Show transliteration & translation'));
      await tester.pumpAndSettle();
      expect(settings.showTranslation, isFalse);

      await tester.tap(find.text(Reciter.fallback.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Reciter.alafasy.name).last);
      await tester.pumpAndSettle();
      expect(settings.reciter, Reciter.alafasy);

      // Reloading from the store returns the same choices, not the defaults.
      await settings.load();
      expect(settings.maddStyle, MaddStyle.ishbaa);
      expect(settings.autoPlayReference, isFalse);
      expect(settings.showTranslation, isFalse);
      expect(settings.reciter, Reciter.alafasy);
    });

    testWidgets('opens on whatever was saved last', (tester) async {
      SharedPreferences.setMockInitialValues({
        'reference_reciter': Reciter.abdulBasit.id,
        'madd_style': MaddStyle.qasr.id,
        'daily_goal_minutes': 30,
      });
      await AppSettings.instance.load();

      await pumpSettings(tester, _MockAuthController());

      expect(find.text(Reciter.abdulBasit.name), findsOneWidget);
      expect(find.textContaining(MaddStyle.qasr.summary), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
    });
  });
}
