import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bayaan/features/stats/stats_screen.dart';

void main() {
  group('StatsScreen', () {
    testWidgets('renders header, key metrics grid, and Tajweed breakdown', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Your Progress'), findsOneWidget);
      expect(find.text('وَقُل رَّبِّ زِدْنِي عِلْمًا'), findsOneWidget);

      // Key metrics
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('Streak'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('Ayahs Practiced'), findsOneWidget);
      expect(find.text('94%'), findsOneWidget);
      expect(find.text('Tajweed Accuracy'), findsOneWidget);
      expect(find.text('650'), findsOneWidget);
      expect(find.text('Total XP'), findsOneWidget);

      // Weekly activity card
      expect(find.text('Weekly Recitation'), findsOneWidget);
      expect(find.text('4h 5m total'), findsOneWidget);

      // Tajweed Mastery
      expect(find.text('Tajweed Mastery'), findsOneWidget);
      expect(find.text('Ghunnah (غنة)'), findsOneWidget);
      expect(find.text('Qalqalah (قلقلة)'), findsOneWidget);

      // Recent practice
      expect(find.text('Recent Practice Sessions'), findsOneWidget);
      expect(find.text('Al-Fatihah'), findsOneWidget);

      // Milestones
      expect(find.text('Milestones & Badges'), findsOneWidget);
      expect(find.text('First Recitation'), findsOneWidget);
    });
  });
}
