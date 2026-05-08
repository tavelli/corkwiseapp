import {RequestError} from "./types.ts";

export type AuthenticatedUser = {
  id: string;
};

export function authenticatedUser(req: Request): AuthenticatedUser {
  const authorization = req.headers.get("Authorization") ??
    req.headers.get("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];

  if (token == null) {
    throw new RequestError(
      401,
      "auth_required",
      "A valid app session is required.",
      true,
    );
  }

  const [, payload] = token.split(".");
  if (payload == null) {
    throw new RequestError(
      401,
      "auth_required",
      "A valid app session is required.",
      true,
    );
  }

  let claims: unknown;
  try {
    claims = JSON.parse(new TextDecoder().decode(base64URLDecode(payload)));
  } catch {
    throw new RequestError(
      401,
      "auth_required",
      "A valid app session is required.",
      true,
    );
  }

  if (claims == null || typeof claims !== "object") {
    throw new RequestError(
      401,
      "auth_required",
      "A valid app session is required.",
      true,
    );
  }

  const subject = (claims as Record<string, unknown>).sub;
  if (typeof subject !== "string" || subject.length === 0) {
    throw new RequestError(
      401,
      "auth_required",
      "A valid app session is required.",
      true,
    );
  }

  return {id: subject};
}

function base64URLDecode(value: string): Uint8Array {
  const base64 = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = base64.padEnd(base64.length + ((4 - base64.length % 4) % 4), "=");
  const binary = atob(padded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}
