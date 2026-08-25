import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/features/audio_compare/compare_data.dart';
import 'package:bayaan/models/models.dart';

void main() {
  group('mistakeBins', () {
    Mistake m(int start, int end) => Mistake(
      charRange: CharRange(start, end),
      isTajweed: true,
      kind: 'replace',
    );

    test('maps each mistake char range to its waveform bin', () {
      // 100 chars split into 10 bins of 10 chars each.
      final bins = mistakeBins([m(0, 10), m(95, 100)], 100, 10);
      expect(bins, {0, 9});
    });

    test('a mistake inside one bin maps to exactly that bin', () {
      final bins = mistakeBins([m(21, 29)], 100, 10);
      expect(bins, {2});
    });

    test('clamps mistakes at the text edge', () {
      final bins = mistakeBins([m(98, 150)], 100, 10);
      expect(bins, {9});
    });

    test('no mistakes means no error bins', () {
      expect(mistakeBins([], 100, 10), isEmpty);
    });

    test('zero-length text yields no bins', () {
      expect(mistakeBins([m(0, 5)], 0, 10), isEmpty);
    });
  });

  group('waveformHeights', () {
    test('is deterministic for a given seed and within bar bounds', () {
      final a = waveformHeights(24, seed: 7);
      final b = waveformHeights(24, seed: 7);
      expect(a, b);
      expect(a, hasLength(24));
      for (final h in a) {
        expect(h, greaterThanOrEqualTo(4));
        expect(h, lessThanOrEqualTo(28));
      }
    });

    test('different seeds give different waveforms', () {
      expect(
        waveformHeights(24, seed: 7),
        isNot(waveformHeights(24, seed: 8)),
      );
    });
  });
}
