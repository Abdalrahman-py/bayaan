import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bayaan/core/app_state.dart';
import 'package:bayaan/core/theme/app_colors.dart';
import 'package:bayaan/features/splash/splash_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Supabase starts app_links, whose platform channels do not exist under
    // flutter_test; silence them so retry can run its real boot sequence.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('com.llfbandit.app_links/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/messages'),
      (_) async => null,
    );
  });

  testWidgets('a failed boot replaces the tagline with a retry action', (
    tester,
  ) async {
    final state = AppState()
      ..booting = false
      ..assetError = true;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: SplashScreen(state: state)));
    await tester.pump();

    expect(find.text("Couldn't load the Quran text"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('retrying clears the failure and boots again', (tester) async {
    final state = AppState()
      ..booting = false
      ..assetError = true;
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: SplashScreen(state: state)));
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(state.assetError, isFalse);
    expect(state.booting, isTrue);
    expect(find.text('Try again'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a healthy boot shows nothing over the native splash colour', (
    tester,
  ) async {
    final state = AppState();
    addTearDown(state.dispose);

    await tester.pumpWidget(MaterialApp(home: SplashScreen(state: state)));
    await tester.pump();

    // Branding belongs to the native launch screen; this route only continues
    // its colour, so a healthy boot draws no text at all.
    expect(find.byType(Text), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.tealStart);

    await tester.pump(const Duration(seconds: 2));
  });
}
