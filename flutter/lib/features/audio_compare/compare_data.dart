import 'dart:math' as math;

import '../../models/models.dart';

/// Maps mistake char ranges (into a verse's uthmani text) onto waveform bins
/// so the user's recitation card can highlight where errors happened.
///
/// [textLength] is the reference text length, [binCount] the number of
/// waveform bars. Each bin covers textLength / binCount chars.
Set<int> mistakeBins(List<Mistake> mistakes, int textLength, int binCount) {
  if (textLength <= 0 || binCount <= 0) return {};
  final bins = <int>{};
  for (final m in mistakes) {
    final start = m.charRange.start.clamp(0, textLength);
    final end = m.charRange.end.clamp(start, textLength);
    if (end == start) continue;
    final bin = ((start / textLength) * binCount).floor();
    bins.add(bin.clamp(0, binCount - 1));
  }
  return bins;
}

/// Deterministic pseudo-random waveform bar heights in [4, 28] — used for the
/// master-recitation card (no per-ayah reference audio is bundled yet).
List<double> waveformHeights(int barCount, {required int seed}) {
  final rng = math.Random(seed);
  return List.generate(
    barCount,
    (_) => 4 + rng.nextDouble() * 24,
  );
}
