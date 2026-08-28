import 'package:bayaan/shared/animation/score_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a clean recitation caps at 95, never 100', () {
    expect(recitationScore(mistakes: 0, sifatErrors: 0), 95);
  });

  test('each issue costs 12 points, tajweed and sifat alike', () {
    expect(recitationScore(mistakes: 1, sifatErrors: 0), 88);
    expect(recitationScore(mistakes: 0, sifatErrors: 1), 88);
    expect(recitationScore(mistakes: 2, sifatErrors: 1), 64);
  });

  test('a rough attempt floors at 15 rather than going negative', () {
    expect(recitationScore(mistakes: 20, sifatErrors: 20), 15);
  });
}
