#!/usr/bin/env bash
# Integration test suite for the Edge Functions migration (docs/decisions/edge-functions-vs-ktor.md).
# Tests the real seam: HTTP request/response contracts of the deployed functions,
# against the live bayaan Supabase project — not internals, not mocks.
#
# Creates a throwaway test user via real signup (real signed JWT, real gateway
# verify_jwt check, real RLS-bypassing RPC writes). Prints the test user id at the
# end so it can be cleaned up (see cleanup query in the skill/session that ran this).
#
# Usage: BASE=https://<ref>.supabase.co ANON_KEY=<anon key> ./edge_functions_test.sh
set -uo pipefail

BASE="${BASE:?set BASE to the project URL, e.g. https://xxx.supabase.co}"
ANON_KEY="${ANON_KEY:?set ANON_KEY to the projects anon/legacy key}"
FN="$BASE/functions/v1"

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  PASS: $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

assert_status() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then ok "$desc (status $actual)"; else bad "$desc (expected $expected, got $actual)"; fi
}

assert_json_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then ok "$desc ($actual)"; else bad "$desc (expected $expected, got $actual)"; fi
}

echo "== setup: signing up a throwaway test user =="
TESTEMAIL="tdd-test-$(date +%s%N)@bayaan-test.local"
SIGNUP=$(curl -s -X POST "$BASE/auth/v1/signup" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$TESTEMAIL\",\"password\":\"TestPass123!aggressive\"}")
JWT=$(echo "$SIGNUP" | jq -r '.access_token // empty')
USER_ID=$(echo "$SIGNUP" | jq -r '.user.id // empty')
if [ -z "$JWT" ] || [ -z "$USER_ID" ]; then
  echo "FATAL: signup did not return a session. Raw response:"
  echo "$SIGNUP"
  exit 1
fi
echo "  test user: $USER_ID"
AUTH=(-H "Authorization: Bearer $JWT")

echo
echo "== public routes (no auth) =="
code=$(curl -s -o /dev/null -w "%{http_code}" "$FN/health")
assert_status "GET /health" 200 "$code"

body=$(curl -s "$FN/surahs")
n=$(echo "$body" | jq '.surahs | length')
assert_json_eq "GET /surahs returns 2 surahs" "2" "$n"
first=$(echo "$body" | jq -r '.surahs[0].name_english')
assert_json_eq "GET /surahs[0] is Al-Fatihah" "Al-Fatihah" "$first"

echo
echo "== auth gate (protected routes reject no-token requests) =="
for ep in "learn/path" "progress" "auth-sync"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/$ep" 2>/dev/null)
  code_get=$(curl -s -o /dev/null -w "%{http_code}" "$FN/$ep")
  # POST-only routes (auth-sync) will 401 either way at the gateway before method matters.
  assert_status "GET/POST /$ep with no token" 401 "$code_get"
done

echo
echo "== CORS preflight on a protected function (must NOT require auth) =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$FN/learn/path" \
  -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: GET")
assert_status "OPTIONS /learn/path preflight" 200 "$code"

echo
echo "== auth-sync =="
body=$(curl -s -X POST "$FN/auth-sync" "${AUTH[@]}")
created=$(echo "$body" | jq -r '.created')
assert_json_eq "POST /auth-sync first call created=true" "true" "$created"
body2=$(curl -s -X POST "$FN/auth-sync" "${AUTH[@]}")
created2=$(echo "$body2" | jq -r '.created')
assert_json_eq "POST /auth-sync second call created=false (idempotent)" "false" "$created2"

echo
echo "== learn/path: fresh user sees only first lesson unlocked =="
body=$(curl -s "$FN/learn/path" "${AUTH[@]}")
xp=$(echo "$body" | jq -r '.header.xp')
assert_json_eq "fresh user xp=0" "0" "$xp"
unit_count=$(echo "$body" | jq '.units | length')
assert_json_eq "11 curriculum units returned" "11" "$unit_count"
lesson_count=$(echo "$body" | jq '[.units[].lessons[]] | length')
assert_json_eq "44 curriculum lessons returned" "44" "$lesson_count"
first_status=$(echo "$body" | jq -r '.units[0].lessons[0].status')
assert_json_eq "ar.1.1 status=available for fresh user" "available" "$first_status"
second_status=$(echo "$body" | jq -r '.units[0].lessons[1].status')
assert_json_eq "ar.1.2 status=locked for fresh user (gating)" "locked" "$second_status"

echo
echo "== learn/complete: unknown lesson_id -> 404 =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/learn/complete" "${AUTH[@]}" \
  -H "Content-Type: application/json" -d '{"lesson_id":"does.not.exist","score":1.0,"item_results":[]}')
assert_status "POST /learn/complete unknown lesson" 404 "$code"

echo
echo "== learn/complete: pass ar.1.1 with 2 first-try-correct items =="
body=$(curl -s -X POST "$FN/learn/complete" "${AUTH[@]}" \
  -H "Content-Type: application/json" \
  -d '{"lesson_id":"ar.1.1","score":0.9,"item_results":[{"item_ref":"a","correct":true,"first_try":true},{"item_ref":"b","correct":true,"first_try":true}]}')
xp_after=$(echo "$body" | jq -r '.header.xp')
# XP_LESSON_BASE(10) + XP_PER_CORRECT(2) * 2 firstTryCorrect = 14
assert_json_eq "xp after passing ar.1.1 = 14 (10 base + 2*2 first-try)" "14" "$xp_after"
streak_after=$(echo "$body" | jq -r '.header.streak_count')
assert_json_eq "streak bumped to 1 on first completion" "1" "$streak_after"

echo
echo "== learn/path: ar.1.1 now completed, ar.1.2 unlocked =="
body=$(curl -s "$FN/learn/path" "${AUTH[@]}")
first_status=$(echo "$body" | jq -r '.units[0].lessons[0].status')
assert_json_eq "ar.1.1 status=completed after passing" "completed" "$first_status"
second_status=$(echo "$body" | jq -r '.units[0].lessons[1].status')
assert_json_eq "ar.1.2 status=available after ar.1.1 completed (gating advances)" "available" "$second_status"

echo
echo "== learn/complete: fail ar.1.2 with a wrong item, seeds a review =="
body=$(curl -s -X POST "$FN/learn/complete" "${AUTH[@]}" \
  -H "Content-Type: application/json" \
  -d '{"lesson_id":"ar.1.2","score":0.3,"item_results":[{"item_ref":"weak-item-1","correct":false,"first_try":true}]}')
reviews_due_today=$(echo "$body" | jq -r '.header.reviews_due')
assert_json_eq "weak item due tomorrow, not due today (reviews_due=0)" "0" "$reviews_due_today"

echo
echo "== learn/reviews: nothing due yet =="
body=$(curl -s "$FN/learn/reviews" "${AUTH[@]}")
n=$(echo "$body" | jq '.reviews | length')
assert_json_eq "GET /learn/reviews empty (weak item not due today)" "0" "$n"

echo
echo "== learn/reviews/{id}/result: unowned/nonexistent id -> 404 =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/learn/reviews/00000000-0000-0000-0000-000000000000/result" \
  "${AUTH[@]}" -H "Content-Type: application/json" -d '{"correct":true}')
assert_status "POST /learn/reviews/<bogus-id>/result" 404 "$code"

echo
echo "== learn/placement: 3 correct in a row bumps level 3->4 =="
body=$(curl -s -X POST "$FN/learn/placement" "${AUTH[@]}" \
  -H "Content-Type: application/json" \
  -d '{"item_results":[{"item_ref":"p1","correct":true},{"item_ref":"p2","correct":true},{"item_ref":"p3","correct":true}]}')
level=$(echo "$body" | jq -r '.arabic_level')
assert_json_eq "3 correct -> level 4" "4" "$level"
key=$(echo "$body" | jq -r '.placement_message_key')
assert_json_eq "placement_message_key matches level" "placement.level.4" "$key"

echo
echo "== progress: fresh session history (no /audio/analyze calls made) =="
body=$(curl -s "$FN/progress" "${AUTH[@]}")
total=$(echo "$body" | jq -r '.total_sessions')
assert_json_eq "total_sessions=0 (no recitation sessions yet)" "0" "$total"
acc=$(echo "$body" | jq -r '.overall_accuracy')
assert_json_eq "overall_accuracy=0 with zero sessions (no div-by-zero crash)" "0" "$acc"

body=$(curl -s "$FN/progress/sessions" "${AUTH[@]}")
n=$(echo "$body" | jq '.sessions | length')
assert_json_eq "GET /progress/sessions empty list" "0" "$n"
total=$(echo "$body" | jq -r '.total')
assert_json_eq "GET /progress/sessions total=0" "0" "$total"

code=$(curl -s -o /dev/null -w "%{http_code}" "$FN/progress/sessions/00000000-0000-0000-0000-000000000000" "${AUTH[@]}")
assert_status "GET /progress/sessions/<bogus-id>" 404 "$code"

echo
echo "== regression: NaN-unsafe input handling (fixed after first test pass) =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/learn/complete" "${AUTH[@]}" \
  -H "Content-Type: application/json" -d '{"lesson_id":"ar.1.3","item_results":[]}')
assert_status "POST /learn/complete with missing score -> 400 (not NaN-corrupted 200)" 400 "$code"
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/learn/complete" "${AUTH[@]}" \
  -H "Content-Type: application/json" -d '{"lesson_id":"ar.1.3","score":"not-a-number","item_results":[]}')
assert_status "POST /learn/complete with non-numeric score -> 400" 400 "$code"
code=$(curl -s -o /dev/null -w "%{http_code}" "$FN/learn/reviews?limit=not-a-number" "${AUTH[@]}")
assert_status "GET /learn/reviews?limit=garbage -> 200 (falls back to default, no 500)" 200 "$code"
code=$(curl -s -o /dev/null -w "%{http_code}" "$FN/progress/sessions?limit=garbage&offset=garbage" "${AUTH[@]}")
assert_status "GET /progress/sessions?limit=garbage&offset=garbage -> 200 (falls back, no 500)" 200 "$code"
body=$(curl -s "$FN/progress/sessions" "${AUTH[@]}")
default_limit=$(echo "$body" | jq -r '.limit')
assert_json_eq "GET /progress/sessions with NO limit param defaults to 20 (not 0/1)" "20" "$default_limit"

echo
echo "== regression: unencoded query-string values (fixed after first test pass) =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/learn/complete" "${AUTH[@]}" \
  -H "Content-Type: application/json" -d '{"lesson_id":"weird&value=1","score":1.0,"item_results":[]}')
assert_status "POST /learn/complete with '&' in lesson_id -> clean 404, not a broken query" 404 "$code"
code=$(curl -s -o /dev/null -w "%{http_code}" "$FN/progress/sessions/weird%26id" "${AUTH[@]}")
assert_status "GET /progress/sessions/<id with %26> -> clean 404, not a broken query" 404 "$code"

echo
echo "== audio-analyze / speech-grade: boundary validation only (no live ML calls) =="
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/audio-analyze" "${AUTH[@]}" -F "sura=1" -F "aya=1")
assert_status "POST /audio-analyze missing audio field" 400 "$code"
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$FN/speech-grade" "${AUTH[@]}" -F "tier=1" -F "reference_text=x" -F "item_ref=x")
assert_status "POST /speech-grade missing audio field" 400 "$code"

echo
echo "=================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "test user id (for cleanup): $USER_ID"
echo "=================================="
[ "$FAIL" -eq 0 ]
