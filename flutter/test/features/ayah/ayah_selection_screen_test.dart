import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/ayah/ayah_selection_screen.dart';
import 'package:bayaan/features/ayah/models/ayah.dart';

void main() {
  const long =
      'هذا نص طويل لآية قرآنية ممتدة على عدة أسطر حتى يصير حجم الخط محكوما بارتفاع الصفحة';

  // Enough text that the fitted font size is bound by page height, so any
  // change to the available height shows up as a change in font size.
  final ayahs = List.generate(
    12,
    (i) => Ayah(sura: 1, number: i + 1, arabicText: long, pageNumber: 1),
  );

  Widget wrap() => MaterialApp(
    home: AyahSelectionScreen(surahNumber: 1, ayahs: ayahs, initialPage: 1),
  );

  double fontSize(WidgetTester tester) =>
      tester.widgetList<Text>(find.textContaining('هذا')).first.style!.fontSize!;

  testWidgets('selecting an ayah leaves the mushaf text size untouched', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    final before = fontSize(tester);

    await tester.tap(find.textContaining('هذا').first);
    await tester.pumpAndSettle();

    expect(fontSize(tester), before);
  });

  testWidgets('long-pressing an ayah offers practising it', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.longPress(find.textContaining('هذا').first);
    await tester.pumpAndSettle();

    expect(find.text('Practice this ayah'), findsOneWidget);
  });
}
