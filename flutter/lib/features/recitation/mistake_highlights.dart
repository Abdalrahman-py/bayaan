import 'package:characters/characters.dart';

import '../../models/models.dart';

/// One stretch of the verse to paint, and whether a tajweed rule was involved.
class Highlight {
  final int start;
  final int end; // exclusive
  final bool isTajweed;
  const Highlight(this.start, this.end, this.isTajweed);

  @override
  bool operator ==(Object other) =>
      other is Highlight &&
      other.start == start &&
      other.end == end &&
      other.isTajweed == isTajweed;

  @override
  int get hashCode => Object.hash(start, end, isTajweed);

  @override
  String toString() => 'Highlight($start, $end, tajweed: $isTajweed)';
}

/// Grows [start, end) outwards to the nearest grapheme cluster boundaries.
///
/// The engine reports mistakes at phoneme precision, so a range can land
/// between a letter and the combining mark that belongs to it — U+0653 MADDAH
/// in `الٓمٓ`, for one. Rendering that half-cluster in its own span strands the
/// mark with no base letter, and it comes out on a dotted circle.
///
/// Snapping to cluster boundaries keeps every mark with its letter while
/// preserving which *sound* the engine flagged, which is the whole point of
/// the screen. Highlights stay per-letter, not per-word.
(int, int) snapToGraphemes(String text, int start, int end) {
  if (text.isEmpty) return (0, 0);
  final boundaries = <int>[0];
  var offset = 0;
  for (final cluster in text.characters) {
    offset += cluster.length;
    boundaries.add(offset);
  }
  final lo = start.clamp(0, text.length);
  final hi = end.clamp(lo, text.length);
  final snappedStart = boundaries.lastWhere((b) => b <= lo);
  final snappedEnd = boundaries.firstWhere(
    (b) => b >= hi,
    orElse: () => text.length,
  );
  return (snappedStart, snappedEnd);
}

/// The exact sounds the engine flagged, safe to render as separate spans.
///
/// Ranges that genuinely overlap are merged — a letter carrying both a tajweed
/// slip and a plain mispronunciation shows as tajweed, the more specific of the
/// two. Distinct letters stay distinct, so the reader sees each mistake
/// separately rather than one blanket highlight.
List<Highlight> mistakeHighlights(String text, List<Mistake> mistakes) {
  if (text.isEmpty || mistakes.isEmpty) return const [];

  final snapped = <Highlight>[];
  for (final m in mistakes) {
    var (start, end) = snapToGraphemes(
      text,
      m.charRange.start,
      m.charRange.end,
    );
    // A zero-width range (an insertion) points between clusters; grow it by one
    // so the reader can still see where the extra sound went.
    if (start == end) {
      final (s2, e2) = snapToGraphemes(text, start, start + 1);
      start = s2;
      end = e2;
    }
    if (start < end) snapped.add(Highlight(start, end, m.isTajweed));
  }
  if (snapped.isEmpty) return const [];

  snapped.sort((a, b) => a.start.compareTo(b.start));
  final merged = <Highlight>[snapped.first];
  for (final h in snapped.skip(1)) {
    final last = merged.last;
    // Strictly overlapping only — two adjacent letters stay two highlights.
    if (h.start < last.end) {
      merged[merged.length - 1] = Highlight(
        last.start,
        h.end > last.end ? h.end : last.end,
        last.isTajweed || h.isTajweed,
      );
    } else {
      merged.add(h);
    }
  }
  return merged;
}

/// The exact sound a single mistake covers, for the breakdown list.
String mistakeSnippet(String text, Mistake m) {
  final (start, end) = snapToGraphemes(
    text,
    m.charRange.start,
    m.charRange.end,
  );
  if (start >= end) return '';
  return text.substring(start, end);
}
