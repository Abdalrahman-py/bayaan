import { CORS_HEADERS } from "./cors.ts";

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

export function err(status: number, error: string, message: string): Response {
  return json({ error, message }, status);
}
