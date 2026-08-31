import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/recitation/ai_analysis_screen.dart';
import 'package:bayaan/models/models.dart';
import 'package:bayaan/services/recitation_controller.dart';

const _verse = Verse(
  sura: 1,
  aya: 2,
  surahNameEn: 'Al-Fatihah',
  surahNameAr: 'الفاتحة',
  uthmani: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ',
);

/// The screen reads whatever `stateFor` returns, so a subclass is all it takes
/// to drive it with a known result.
class _SeededController extends RecitationController {
  final RecitationUiState state;
  _SeededController(this.state);

  @override
  RecitationUiState stateFor(int sura, int aya) => state;
}

Widget wrap(RecitationUiState state) => MaterialApp(
  home: AiAnalysisScreen(
    controller: _SeededController(state),
    sura: 1,
    aya: 2,
  ),
);

void main() {
  final tajweed = const Mistake(
    charRange: CharRange(0, 5),
    isTajweed: true,
    kind: 'replace',
    ruleNameEn: 'Madd Munfasil',
    ruleNameAr: 'مد منفصل',
    expectedLen: 4,
    gotLen: 2,
  );
  final plain = const Mistake(
    charRange: CharRange(8, 12),
    isTajweed: false,
    kind: 'delete',
  );
  // The engine's real vocabulary (spike/s1_results_mine.txt), not a tidied-up
  // stand-in: these are the exact strings that have to survive to the screen.
  const sifat = SifatError(
    phonemesGroup: 'د',
    attribute: 'shidda_or_rakhawa',
    predicted: 'rikhw',
    expected: 'shadeed',
  );

  testWidgets('lists every mistake instead of hiding them behind a tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(ResultState(_verse, [tajweed, plain], const [sifat], false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('What to fix'), findsOneWidget);
    // The old screen told the reader to go hunting; nothing should now.
    expect(find.textContaining('Tap a highlighted word'), findsNothing);

    // Tajweed and pronunciation are separate sections, counted separately.
    expect(find.text('Tajweed rule · 1'), findsOneWidget);
    expect(find.text('Pronunciation · 1'), findsOneWidget);
    expect(find.text('Letter quality · 1'), findsOneWidget);

    expect(find.text('Madd Munfasil'), findsOneWidget);
    expect(
      find.text('Hold 4 counts — yours was too short'),
      findsOneWidget,
    );
    expect(find.text('Sound left out'), findsOneWidget);
    // No raw engine identifier reaches the screen.
    expect(find.text('Strength'), findsOneWidget);
    expect(
      find.text('Should be a firm stop (shadeed) — you said flowing (rikhw)'),
      findsOneWidget,
    );
    expect(find.textContaining('shidda_or_rakhawa'), findsNothing);
    // Sifat carry no character range, so the ayah above shows no mark for them.
    expect(
      find.textContaining('not marked on the ayah above'),
      findsOneWidget,
    );
  });

  testWidgets('a section is absent when that error kind did not occur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      wrap(ResultState(_verse, [tajweed], const [], false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tajweed rule · 1'), findsOneWidget);
    expect(find.textContaining('Pronunciation ·'), findsNothing);
    expect(find.textContaining('Letter quality ·'), findsNothing);
  });
}
