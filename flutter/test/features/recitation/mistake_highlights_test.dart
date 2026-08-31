import 'package:bayaan/features/recitation/mistake_highlights.dart';
import 'package:bayaan/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Mistake at(int start, int end, {bool tajweed = true}) => Mistake(
  charRange: CharRange(start, end),
  isTajweed: tajweed,
  kind: 'replace',
);

void main() {
  // ا[0] ل[1] ٓ[2] م[3] ٓ[4] — the maddahs at 2 and 4 are combining marks that
  // belong to the letter before them.
  const muqattaat = 'الٓمٓ';

  group('snapToGraphemes', () {
    test('pulls a combining mark in with its base letter', () {
      // A range ending at 2 would strand the maddah on a dotted circle.
      expect(snapToGraphemes(muqattaat, 1, 2), (1, 3));
    });

    test('leaves a range that already sits on boundaries alone', () {
      expect(snapToGraphemes(muqattaat, 0, 1), (0, 1));
      expect(snapToGraphemes(muqattaat, 3, 5), (3, 5));
    });

    test('clamps out-of-range offsets instead of throwing', () {
      expect(snapToGraphemes(muqattaat, 0, 99), (0, 5));
      expect(snapToGraphemes('', 0, 3), (0, 0));
    });
  });

  group('mistakeHighlights', () {
    test('keeps each flagged sound separate rather than merging the word', () {
      // This is the regression that matters: three letters, three mistakes,
      // three distinct highlights — not one blanket span over the ayah.
      final spans = mistakeHighlights(muqattaat, [
        at(0, 1),
        at(1, 2),
        at(3, 4),
      ]);
      expect(spans, [
        const Highlight(0, 1, true),
        const Highlight(1, 3, true),
        const Highlight(3, 5, true),
      ]);
    });

    test('adjacent letters stay two highlights, not one', () {
      final spans = mistakeHighlights('بسم', [at(0, 1), at(1, 2)]);
      expect(spans, hasLength(2));
    });

    test('merges only genuinely overlapping ranges', () {
      final spans = mistakeHighlights('بسم', [at(0, 2), at(1, 3)]);
      expect(spans, [const Highlight(0, 3, true)]);
    });

    test('an overlap carrying both error kinds shows as tajweed', () {
      final spans = mistakeHighlights('بسم', [
        at(0, 2, tajweed: false),
        at(1, 3, tajweed: true),
      ]);
      expect(spans.single.isTajweed, isTrue);
    });

    test('a plain mispronunciation alone stays plain', () {
      expect(
        mistakeHighlights('بسم', [at(0, 1, tajweed: false)]).single.isTajweed,
        isFalse,
      );
    });

    test('a zero-width insertion still marks one cluster', () {
      expect(mistakeHighlights(muqattaat, [at(1, 1)]), [
        const Highlight(1, 3, true),
      ]);
    });

    test('an insertion at the very end marks the last cluster', () {
      // Real engine output: `uthmani_pos: [len, len]` when the reciter added a
      // sound after the last letter. Growing forward finds nothing, so this
      // used to vanish from the ayah while still being counted on the ring.
      expect(mistakeHighlights(muqattaat, [at(5, 5)]), [
        const Highlight(3, 5, true),
      ]);
    });

    test('empty inputs yield nothing', () {
      expect(mistakeHighlights('', [at(0, 3)]), isEmpty);
      expect(mistakeHighlights('بسم', const []), isEmpty);
    });
  });

  group('mistakeSnippet', () {
    test('returns the flagged letter with its mark, not the whole word', () {
      expect(mistakeSnippet(muqattaat, at(1, 2)), 'لٓ');
      expect(mistakeSnippet(muqattaat, at(0, 1)), 'ا');
      expect(mistakeSnippet(muqattaat, at(3, 4)), 'مٓ');
    });

    test('an insertion gets the same cluster the verse marks, not a blank', () {
      // The chip in the breakdown list and the mark on the ayah are two views
      // of one mistake; a blank chip beside a marked letter reads as a bug.
      expect(mistakeSnippet(muqattaat, at(1, 1)), 'لٓ');
      expect(mistakeSnippet(muqattaat, at(5, 5)), 'مٓ');
    });
  });
}
