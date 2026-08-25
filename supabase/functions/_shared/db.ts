// Minimal PostgREST client — service-role key bypasses RLS the same way the
// Ktor backend's HikariCP connection does (RLS is ON with zero policies on
// every learn_* table). No SDK dependency needed. Ported/generalized from
// spike/edge-functions' inline pgRest().
//
// ponytail: RPC writes (learn_complete etc.) are SECURITY DEFINER + granted to
// `authenticated`, meant to be callable with the user's own JWT (no service-role
// needed for writes — see docs/decisions/edge-functions-vs-ktor.md). Reads use
// service-role regardless, since RLS has zero policies. Using service-role for
// both here is one fewer auth path to reason about; revisit if that grant ever
// needs to mean something (e.g. a future direct-client RPC call).
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";

const REST_HEADERS = {
  "Content-Type": "application/json",
  apikey: SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
};

// PostgREST filter values go straight into a query string — a client-controlled
// value containing "&" or "%" would corrupt the filter (or bleed into other
// params) if interpolated raw. Every value in a pgSelect/pgCount filter that
// didn't originate server-side (a UUID we generated, an ISO date we computed)
// must be passed through this first.
export function qs(value: string): string {
  return encodeURIComponent(value);
}

// Kotlin's routes wrap path-param UUIDs in `UUID.fromString(...)` and catch
// IllegalArgumentException -> 404 before ever touching the DB. A raw string
// filtered against a uuid-typed column instead makes Postgres throw a cast
// error, which pgSelect/pgRpc turn into a generic 500 — same bug shape as the
// query-string-injection issue this file's other helper fixes, different root
// cause. Route handlers must check this before using a path param as an id.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function isUuid(value: string): boolean {
  return UUID_RE.test(value);
}

export async function pgSelect<T>(table: string, query: string): Promise<T[]> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, { headers: REST_HEADERS });
  if (!r.ok) throw new Error(`select ${table}: ${r.status} ${await r.text()}`);
  return r.json();
}

export async function pgUpsert(
  table: string,
  body: unknown,
  onConflict: string,
  ignoreDuplicates = false,
): Promise<void> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      ...REST_HEADERS,
      Prefer: `resolution=${ignoreDuplicates ? "ignore" : "merge"}-duplicates,return=minimal,on_conflict=${onConflict}`,
    },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`upsert ${table}: ${r.status} ${await r.text()}`);
}

export async function pgInsert(table: string, body: unknown): Promise<void> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: { ...REST_HEADERS, Prefer: "return=minimal" },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error(`insert ${table}: ${r.status} ${await r.text()}`);
}

export async function pgCount(table: string, query: string): Promise<number> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/${table}?${query}`, {
    headers: { ...REST_HEADERS, Prefer: "count=exact" },
  });
  if (!r.ok) throw new Error(`count ${table}: ${r.status} ${await r.text()}`);
  const range = r.headers.get("content-range") ?? "*/0";
  return Number(range.split("/")[1] ?? 0);
}

export async function pgRpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: REST_HEADERS,
    body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`rpc ${fn}: ${r.status} ${await r.text()}`);
  return r.json();
}
