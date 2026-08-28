import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/recitation/recording_screen.dart';
import 'package:bayaan/services/app_settings.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:bayaan/services/recitation_controller.dart';
import 'package:bayaan/services/reciter_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('renders verse card and tap to recite button in ready state', (
    tester,
  ) async {
    final controller = RecitationController();
    final auth = AuthController();

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          controller: controller,
          auth: auth,
          sura: 1,
          aya: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TAP TO RECITE'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.textContaining('Al-Fatihah'), findsWidgets);
  });

  testWidgets('offers the chosen shaikh to listen to before reciting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'reference_reciter': Reciter.alafasy.id,
    });
    await AppSettings.instance.load();

    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          controller: RecitationController(),
          auth: AuthController(),
          sura: 1,
          aya: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Listen to ${Reciter.alafasy.shortName}'),
      findsOneWidget,
    );
  });

  testWidgets('falls back to the default shaikh when none was chosen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecordingScreen(
          controller: RecitationController(),
          auth: AuthController(),
          sura: 1,
          aya: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Listen to ${Reciter.fallback.shortName}'),
      findsOneWidget,
    );
  });
}
