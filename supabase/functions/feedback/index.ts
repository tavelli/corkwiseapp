import { authenticatedUser } from "../analyze-wine-menu/domain/auth.ts";
import { restHeaders, restURL } from "../analyze-wine-menu/domain/rest.ts";
import { RequestError } from "../analyze-wine-menu/domain/types.ts";

const MIN_RETRY_COMMENT_LENGTH = Number(
  Deno.env.get("MIN_RETRY_COMMENT_LENGTH") ?? "12",
);
const RETRY_GRANT_LIMIT_DAYS = Number(
  Deno.env.get("RETRY_GRANT_LIMIT_DAYS") ?? "30",
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FeedbackRequest = {
  analysisId: string;
  appUserId: string;
  rating: "useful" | "not_useful";
  comment: string | null;
  source: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authUser = authenticatedUser(req);

    if (req.method !== "POST") {
      throw new RequestError(
        405,
        "invalid_request",
        "Only POST requests are supported.",
        false,
      );
    }

    const payload = validateFeedbackRequest(await req.json());
    const analysis = await analysisForFeedback(payload.analysisId);

    if (
      analysis == null ||
      analysis.keychain_app_user_id !== payload.appUserId
    ) {
      throw new RequestError(
        403,
        "invalid_request",
        "Feedback does not match this analysis.",
        false,
      );
    }

    const feedbackId = await insertFeedback({
      ...payload,
      supabaseAuthUserId: authUser.id,
      keychainAppUserId: analysis.keychain_app_user_id,
      freeScanUsed: analysis.free_scan_used,
    });

    let retryCreditId: string | null = null;
    if (isRetryEligible(payload)) {
      retryCreditId = await maybeCreateRetryCredit({
        feedbackId,
        supabaseAuthUserId: authUser.id,
        keychainAppUserId: analysis.keychain_app_user_id,
      });

      if (retryCreditId != null) {
        await markRetryGranted(feedbackId);
      }
    }

    return Response.json(
      retryCreditId == null
        ? { ok: true, retryGranted: false }
        : { ok: true, retryGranted: true, retryCreditId },
      { status: 200, headers: corsHeaders },
    );
  } catch (error) {
    if (error instanceof RequestError) {
      return Response.json(error.responseBody, {
        status: error.status,
        headers: corsHeaders,
      });
    }

    console.error(
      "feedback failed:",
      error instanceof Error ? error.message : "unknown error",
    );

    return Response.json(
      {
        error: "feedback_failed",
        message: "Something went wrong while saving feedback.",
        retrySuggested: true,
      },
      { status: 500, headers: corsHeaders },
    );
  }
});

function validateFeedbackRequest(input: unknown): FeedbackRequest {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      400,
      "invalid_request",
      "Request body must be a JSON object.",
      false,
    );
  }

  const candidate = input as Record<string, unknown>;
  const analysisId = stringOrNull(candidate.analysisId);
  const appUserId = stringOrNull(candidate.appUserId);
  const rating = stringOrNull(candidate.rating);
  const source = stringOrNull(candidate.source) ?? "result_end_card";
  const comment = stringOrNull(candidate.comment);

  if (analysisId == null || isUUID(analysisId) === false) {
    throw new RequestError(
      400,
      "invalid_request",
      "analysisId must be a valid UUID.",
      false,
    );
  }

  if (appUserId == null || isUUID(appUserId) === false) {
    throw new RequestError(
      400,
      "invalid_request",
      "appUserId must be a valid UUID.",
      false,
    );
  }

  if (rating !== "useful" && rating !== "not_useful") {
    throw new RequestError(
      400,
      "invalid_request",
      "rating is invalid.",
      false,
    );
  }

  if (comment != null && comment.length > 1_000) {
    throw new RequestError(
      400,
      "invalid_request",
      "comment is too long.",
      false,
    );
  }

  return {
    analysisId,
    appUserId,
    rating,
    comment,
    source,
  };
}

async function analysisForFeedback(
  analysisId: string,
): Promise<{ keychain_app_user_id: string; free_scan_used: boolean } | null> {
  const query = new URL(`${restURL()}/analyses`);
  query.searchParams.set("select", "keychain_app_user_id,free_scan_used");
  query.searchParams.set("id", `eq.${analysisId}`);
  query.searchParams.set("success", "eq.true");
  query.searchParams.set("limit", "1");

  const response = await fetch(query, {
    method: "GET",
    headers: restHeaders(),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "feedback_failed",
      "Something went wrong while saving feedback.",
      true,
    );
  }

  const [row] = await response.json() as Array<{
    keychain_app_user_id: string;
    free_scan_used: boolean;
  }>;
  return row ?? null;
}

async function insertFeedback(
  input: FeedbackRequest & {
    supabaseAuthUserId: string;
    keychainAppUserId: string;
    freeScanUsed: boolean;
  },
): Promise<string> {
  const response = await fetch(`${restURL()}/analysis_feedback`, {
    method: "POST",
    headers: restHeaders({
      Prefer: "return=representation",
    }),
    body: JSON.stringify({
      supabase_auth_user_id: input.supabaseAuthUserId,
      keychain_app_user_id: input.keychainAppUserId,
      analysis_id: input.analysisId,
      rating: input.rating,
      comment: input.comment,
      source: input.source,
      free_scan_used: input.freeScanUsed,
    }),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "feedback_failed",
      "Something went wrong while saving feedback.",
      true,
    );
  }

  const [row] = await response.json() as Array<{ id: string }>;
  return row.id;
}

async function maybeCreateRetryCredit(input: {
  feedbackId: string;
  supabaseAuthUserId: string;
  keychainAppUserId: string;
}): Promise<string | null> {
  if (await hasRecentRetryGrant(input.keychainAppUserId)) {
    return null;
  }

  const response = await fetch(`${restURL()}/analysis_retry_credits`, {
    method: "POST",
    headers: restHeaders({
      Prefer: "return=representation",
    }),
    body: JSON.stringify({
      supabase_auth_user_id: input.supabaseAuthUserId,
      keychain_app_user_id: input.keychainAppUserId,
      feedback_id: input.feedbackId,
      reason: "negative_feedback",
    }),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "feedback_failed",
      "Something went wrong while saving feedback.",
      true,
    );
  }

  const [row] = await response.json() as Array<{ id: string }>;
  return row.id;
}

async function hasRecentRetryGrant(appUserId: string): Promise<boolean> {
  const since = new Date(
    Date.now() - RETRY_GRANT_LIMIT_DAYS * 24 * 60 * 60 * 1_000,
  ).toISOString();
  const query = new URL(`${restURL()}/analysis_retry_credits`);
  query.searchParams.set("select", "id");
  query.searchParams.set("keychain_app_user_id", `eq.${appUserId}`);
  query.searchParams.set("created_at", `gte.${since}`);
  query.searchParams.set("limit", "1");

  const response = await fetch(query, {
    method: "GET",
    headers: restHeaders(),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "feedback_failed",
      "Something went wrong while saving feedback.",
      true,
    );
  }

  const rows = await response.json() as Array<{ id: string }>;
  return rows.length > 0;
}

async function markRetryGranted(feedbackId: string): Promise<void> {
  const response = await fetch(
    `${restURL()}/analysis_feedback?id=eq.${feedbackId}`,
    {
      method: "PATCH",
      headers: restHeaders(),
      body: JSON.stringify({ retry_granted: true }),
    },
  );

  if (response.ok === false) {
    throw new RequestError(
      500,
      "feedback_failed",
      "Something went wrong while saving feedback.",
      true,
    );
  }
}

function isRetryEligible(payload: FeedbackRequest): boolean {
  return payload.rating === "not_useful" &&
    (payload.comment?.trim().length ?? 0) >= MIN_RETRY_COMMENT_LENGTH;
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmedValue = value.trim();
  return trimmedValue.length === 0 ? null : trimmedValue;
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
