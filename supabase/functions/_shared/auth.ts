// Ported from spike/edge-functions — with verify_jwt=true, Supabase injects
// verified claims into x-supabase-auth; falls back to decoding the Bearer JWT
// payload directly if that header is absent.
export function userIdFromRequest(req: Request): string | null {
  const authHeader = req.headers.get("x-supabase-auth");
  if (authHeader) {
    try {
      const claims = JSON.parse(authHeader);
      if (claims.sub) return claims.sub;
    } catch { /* fall through */ }
  }
  const bearer = req.headers.get("authorization") ?? "";
  const token = bearer.replace(/^Bearer\s+/i, "");
  if (!token) return null;
  try {
    const payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
    return payload.sub ?? null;
  } catch {
    return null;
  }
}
