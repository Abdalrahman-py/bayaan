// Port of SurahRoutes.kt — GET /surahs. Hardcoded, matches Ktor exactly.
import { handlePreflight } from "../_shared/cors.ts";
import { json } from "../_shared/response.ts";

const SURAHS = [
  { number: 1, name_arabic: "الفاتحة", name_english: "Al-Fatihah", verse_count: 7, available: true },
  { number: 98, name_arabic: "البينة", name_english: "Al-Bayyinah", verse_count: 8, available: true },
];

Deno.serve((req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;
  return json({ surahs: SURAHS });
});
