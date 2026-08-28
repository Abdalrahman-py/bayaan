// Pins the placement gating rule (supabase/functions/_shared/placement.ts).
// The curriculum is 8 arabic units (ar.1..ar.8, positions 1-8) plus 3 tajweed
// units, and the placement ladder in handlePlacement clamps to 0-8 — so the
// off-by-one at each end is the thing worth holding still.
import { assert, assertEquals } from "jsr:@std/assert";
import { placementUnlocks } from "../functions/_shared/placement.ts";

const arabic = (position: number) => ({ track: "arabic", position });
const tajweed = (position: number) => ({ track: "tajweed", position });

Deno.test("level 0 opens only the first unit", () => {
  assert(placementUnlocks(arabic(1), 0));
  assertEquals(placementUnlocks(arabic(2), 0), false);
});

Deno.test("level N opens units 1..N and the one after", () => {
  for (const position of [1, 2, 3, 4, 5, 6, 7]) {
    assert(placementUnlocks(arabic(position), 6), `unit ${position} at level 6`);
  }
  // Unit 8 is still earned by finishing unit 7.
  assertEquals(placementUnlocks(arabic(8), 6), false);
});

Deno.test("a top placement opens the whole arabic track", () => {
  for (const position of [1, 2, 3, 4, 5, 6, 7, 8]) {
    assert(placementUnlocks(arabic(position), 8), `unit ${position} at level 8`);
  }
});

Deno.test("the tajweed track is never placed", () => {
  assertEquals(placementUnlocks(tajweed(9), 8), false);
  assertEquals(placementUnlocks(tajweed(11), 8), false);
});
