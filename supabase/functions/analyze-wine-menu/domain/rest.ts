import { RequestError } from "./types.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

export function restURL(): string {
  if (SUPABASE_URL == null || SUPABASE_SERVICE_ROLE_KEY == null) {
    throw new RequestError(
      500,
      "analysis_failed",
      "The backend is missing required Supabase configuration.",
      false,
    );
  }

  return `${SUPABASE_URL}/rest/v1`;
}

export function restHeaders(extraHeaders: HeadersInit = {}): HeadersInit {
  return {
    apikey: SUPABASE_SERVICE_ROLE_KEY!,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
    ...extraHeaders,
  };
}
