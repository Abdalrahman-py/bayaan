/// Linear interpolation of an animated score counter.
/// [t] is the animation value in [0, 1]; returns the rounded intermediate.
int interpolateScore(double t, {required int from, required int to}) =>
    (from + (to - from) * t).round();
