import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/recitation/highlighted_verse.dart';
import 'package:bayaan/features/recitation/mistake_highlights.dart';

void main() {
  const muqattaat = 'الٓمٓ';

  Widget wrap(List<Highlight> highlights, {String text = muqattaat}) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: HighlightedVerse(
              text: text,
              highlights: highlights,
              style: const TextStyle(fontSize: 24),
              tajweedColor: const Color(0xFFD95A3B),
              plainColor: const Color(0xFFC084FC),
            ),
          ),
        ),
      );

  testWidgets('lays the ayah out as a single run, whatever is highlighted', (
    tester,
  ) async {
    // One Text/RichText would mean spans; the whole point is that there is
    // exactly one painted run regardless of how many mistakes there are.
    await tester.pumpWidget(wrap(const []));
    await tester.pumpAndSettle();
    final bare = tester.getSize(find.byType(CustomPaint).first);

    await tester.pumpWidget(
      wrap(const [Highlight(0, 1, true), Highlight(1, 3, false)]),
    );
    await tester.pumpAndSettle();
    final marked = tester.getSize(find.byType(CustomPaint).first);

    // Highlighting must not reflow or resize the text.
    expect(marked, bare);
  });

  testWidgets('renders without throwing for edge-case ranges', (tester) async {
    await tester.pumpWidget(
      wrap(const [Highlight(0, 5, true)]),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(wrap(const [], text: ''));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('lays the ayah across the full width so centring has room', () {
    final painter = layoutVerse(
      text: muqattaat,
      style: const TextStyle(fontSize: 24),
      width: 320,
    );
    // Without minWidth the box collapses to the glyphs and the ayah renders
    // flush left instead of centred.
    expect(painter.width, 320);
  });
}
