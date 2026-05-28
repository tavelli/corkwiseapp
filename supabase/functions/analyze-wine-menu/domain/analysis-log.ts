import { PROMPT_VERSION } from "./prompt.ts";
import { restHeaders, restURL } from "./rest.ts";
import { type AnalysisAccessSource, RequestError } from "./types.ts";

export type AnalysisAttemptInput = {
  supabaseAuthUserId: string;
  appUserId: string;
  isPaid: boolean;
  allowed: boolean;
  decisionReason: string;
  accessSource: AnalysisAccessSource;
  scanSource?: "attachment" | "url";
  attachmentCount?: number;
  purchaseMode?: string;
  categoryPreference?: string;
  buildConfiguration?: string;
};

export type CompleteAnalysisInput = {
  analysisId: string;
  provider?: string;
  modelVersion?: string;
  success: boolean;
  errorCode?: string;
  aiModelDurationMilliseconds?: number;
  estimatedCostUsd?: number;
  inputTokens?: number;
  outputTokens?: number;
  freeScanUsed?: boolean;
  retryCreditUsedId?: string;
  resultPayload?: unknown;
};

export async function createAnalysisAttempt(
  input: AnalysisAttemptInput,
): Promise<string> {
  const body = {
    supabase_auth_user_id: input.supabaseAuthUserId,
    keychain_app_user_id: input.appUserId,
    is_paid: input.isPaid,
    allowed: input.allowed,
    decision_reason: input.decisionReason,
    access_source: input.accessSource,
    scan_source: input.scanSource,
    attachment_count: input.attachmentCount,
    purchase_mode: input.purchaseMode,
    category_preference: input.categoryPreference,
    build_configuration: input.buildConfiguration,
    prompt_version: PROMPT_VERSION,
  };

  const response = await fetch(`${restURL()}/analyses`, {
    method: "POST",
    headers: restHeaders({
      Prefer: "return=representation",
    }),
    body: JSON.stringify(body),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while preparing the scan.",
      true,
    );
  }

  const [row] = await response.json() as Array<{ id: string }>;
  if (row?.id == null) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while preparing the scan.",
      true,
    );
  }

  return row.id;
}

export async function completeAnalysis(
  input: CompleteAnalysisInput,
): Promise<void> {
  const body: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
    completed_at: new Date().toISOString(),
    success: input.success,
    prompt_version: PROMPT_VERSION,
  };

  if (input.provider != null) {
    body.provider = input.provider;
  }
  if (input.modelVersion != null) {
    body.model_version = input.modelVersion;
  }
  if (input.errorCode != null) {
    body.error_code = input.errorCode;
  }
  if (input.aiModelDurationMilliseconds != null) {
    body.ai_model_duration_milliseconds = input.aiModelDurationMilliseconds;
  }
  if (input.estimatedCostUsd != null) {
    body.estimated_cost_usd = input.estimatedCostUsd;
  }
  if (input.inputTokens != null) {
    body.input_tokens = input.inputTokens;
  }
  if (input.outputTokens != null) {
    body.output_tokens = input.outputTokens;
  }
  if (input.freeScanUsed != null) {
    body.free_scan_used = input.freeScanUsed;
  }
  if (input.retryCreditUsedId != null) {
    body.retry_credit_used_id = input.retryCreditUsedId;
  }
  if (input.resultPayload != null) {
    body.result_payload = input.resultPayload;
  }

  const response = await fetch(
    `${restURL()}/analyses?id=eq.${input.analysisId}`,
    {
      method: "PATCH",
      headers: restHeaders(),
      body: JSON.stringify(body),
    },
  );

  if (response.ok === false) {
    console.error("analysis log update failed", await response.text());
  }
}
