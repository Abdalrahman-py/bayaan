// Port of the Ktor GET /health route. Public, no auth — used to check the
// stack is up (and as a deploy smoke test).
import { handlePreflight } from "../_shared/cors.ts";
import { json } from "../_shared/response.ts";

Deno.serve((req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;
  return json({ status: "ok" });
});
