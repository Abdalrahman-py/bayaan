import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/recitation/recording_screen.dart';
import 'package:bayaan/services/auth_controller.dart';
import 'package:bayaan/services/recitation_controller.dart';

void main() {
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
}
