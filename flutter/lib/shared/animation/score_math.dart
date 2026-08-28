/// Linear interpolation of an animated score counter.
/// [t] is the animation value in [0, 1]; returns the rounded intermediate.
int interpolateScore(double t, {required int from, required int to}) =>
    (from + (to - from) * t).round();

/// How close a recitation was, as a percentage.
///
/// Derived from the grader's verdict — the phoneme and sifat differences the
/// engine reports — not from comparing the reciter's waveform against a
/// qari's. Each issue costs 12 points, floored at 15 so a rough attempt still
/// reads as progress, and capped at 95 because the engine never claims
/// certainty. The analysis and compare screens must agree, so both call this.
int recitationScore({required int mistakes, required int sifatErrors}) =>
    (100 - ((mistakes + sifatErrors) * 12)).clamp(15, 95);
