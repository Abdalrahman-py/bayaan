// Placement gating — how a learner's arabic_level (0-8, written by
// record_placement) turns into unlocked units on /learn/path.
//
// Lives here rather than inside learn/index.ts so the rule can be tested
// without importing a module that calls Deno.serve at load time.

export interface PlacedUnit {
  track: string;
  position: number;
}

/**
 * Level N means the learner demonstrated units 1..N, so those units plus the
 * next one open immediately — available, never completed. Marking them
 * completed would invent lesson_progress rows (and best_score/attempts) for
 * work nobody did; the learner can still walk back through anything below
 * their level.
 *
 * Only the arabic track is placed. The tajweed units stay sequential: nothing
 * in the placement test measures tajweed.
 */
export function placementUnlocks(unit: PlacedUnit, arabicLevel: number): boolean {
  return unit.track === "arabic" && unit.position <= arabicLevel + 1;
}
