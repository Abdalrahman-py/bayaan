// Shared across all functions. Native app has no CORS (browser-only mechanism),
// but Flutter web dev needs it — wildcard is safe here since auth is Bearer-token
// (not cookies), so there's no credentialed-request risk from a permissive origin.
export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

export function handlePreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  return null;
}
