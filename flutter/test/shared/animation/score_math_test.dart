import 'package:flutter_test/flutter_test.dart';

import 'package:bayaan/shared/animation/score_math.dart';

void main() {
  group('interpolateScore', () {
    test('returns the start score at t=0 and the end score at t=1', () {
      expect(interpolateScore(0, from: 40, to: 100), 40);
      expect(interpolateScore(1, from: 40, to: 100), 100);
    });

    test('interpolates linearly mid-way', () {
      expect(interpolateScore(0.5, from: 40, to: 100), 70);
    });

    test('rounds intermediate values', () {
      expect(interpolateScore(0.33, from: 0, to: 100), 33);
    });
  });
}
