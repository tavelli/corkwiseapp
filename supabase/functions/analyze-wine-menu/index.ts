import {
  checkFreeScanAllowance,
  consumeFreeScan,
  upsertAppInstallation,
} from "./domain/app-installations.ts";
import {
  completeAnalysis,
  createAnalysisAttempt,
} from "./domain/analysis-log.ts";
import { authenticatedUser } from "./domain/auth.ts";
import { checkEntitlement, type EntitlementState } from "./domain/adapty.ts";
import { PROMPT_VERSION } from "./domain/prompt.ts";
import { MAX_REQUEST_BYTES, validateAnalyzeRequest } from "./domain/request.ts";
import {
  scanAccessForRequest,
  validateScanAccessRequest,
} from "./domain/scan-access.ts";
import { normalizeScanResult } from "./domain/normalize.ts";
import {
  availableRetryCredit,
  consumeRetryCredit,
} from "./domain/retry-credits.ts";
import { makeProvider } from "./providers/factory.ts";
import {
  type AnalysisAccessSource,
  type AnalyzeWineMenuRequest,
  RequestError,
  type WineAnalysisErrorResponse,
} from "./domain/types.ts";

const FREE_SCAN_LIMIT = Number(Deno.env.get("FREE_SCAN_LIMIT") ?? "0");
const ALLOW_DEBUG_ENTITLEMENT_BYPASS =
  Deno.env.get("ALLOW_DEBUG_ENTITLEMENT_BYPASS") === "true";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  let analysisId: string | null = null;

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("analyze-wine-menu invoked", new Date().toISOString());
    const authUser = authenticatedUser(req);

    if (req.method !== "POST") {
      throw new RequestError(
        405,
        "invalid_request",
        "Only POST requests are supported.",
        false,
      );
    }

    const rawBody = await req.text();
    if (rawBody.length === 0) {
      throw new RequestError(
        400,
        "invalid_request",
        "Request body is required.",
        false,
      );
    }

    if (new TextEncoder().encode(rawBody).byteLength > MAX_REQUEST_BYTES) {
      throw new RequestError(
        413,
        "image_too_large",
        "The selected file is too large. Please try again with a smaller image or PDF.",
        true,
      );
    }

    let parsedBody: unknown;
    try {
      parsedBody = JSON.parse(rawBody);
    } catch {
      throw new RequestError(
        400,
        "invalid_request",
        "Request body must be valid JSON.",
        false,
      );
    }

    const action = parsedBody != null && typeof parsedBody === "object"
      ? (parsedBody as Record<string, unknown>).action
      : null;
    if (action === "scan_access") {
      const accessRequest = validateScanAccessRequest(parsedBody);
      const accessResponse = await scanAccessForRequest(
        accessRequest,
        authUser.id,
        FREE_SCAN_LIMIT,
      );

      return Response.json(accessResponse, {
        status: 200,
        headers: corsHeaders,
      });
    }

    const requestBody = validateAnalyzeRequest(parsedBody);
    const entitlement = await entitlementForRequest(requestBody);
    await upsertAppInstallation(
      requestBody.appUserId,
      authUser.id,
      entitlement.appleOriginalTransactionId,
      requestBody.buildConfiguration,
    );

    const shouldConsumeFreeScan = entitlement.isPaid === false;
    let accessSource: AnalysisAccessSource = entitlement.isPaid
      ? "paid"
      : "blocked";
    let decisionReason = entitlement.isPaid ? "paid_entitlement" : "";
    let retryCreditId: string | null = null;

    if (shouldConsumeFreeScan) {
      if (FREE_SCAN_LIMIT <= 0) {
        const retryCredit = await availableRetryCredit(requestBody.appUserId);
        if (retryCredit == null) {
          decisionReason = "free_scans_disabled";
          analysisId = await createAnalysisAttempt({
            supabaseAuthUserId: authUser.id,
            appUserId: requestBody.appUserId,
            isPaid: false,
            allowed: false,
            decisionReason,
            accessSource: "blocked",
            scanSource: requestBody.source.kind,
            attachmentCount: attachmentCountForRequest(requestBody),
            purchaseMode: requestBody.purchaseMode,
            categoryPreference: requestBody.categoryPreference,
            buildConfiguration: requestBody.buildConfiguration,
          });

          throw new RequestError(
            403,
            "entitlement_required",
            "An active CorkWise subscription is required to scan.",
            false,
          );
        }

        accessSource = "retry_credit";
        decisionReason = "retry_credit_available";
        retryCreditId = retryCredit.id;
      }

      if (FREE_SCAN_LIMIT > 0) {
        const freeScanAllowance = await checkFreeScanAllowance(
          requestBody.appUserId,
          FREE_SCAN_LIMIT,
        );

        if (freeScanAllowance.allowed) {
          accessSource = "free_scan";
          decisionReason = "free_scan_available";
        } else {
          const retryCredit = await availableRetryCredit(requestBody.appUserId);
          if (retryCredit == null) {
            decisionReason = "free_scan_exhausted";
            analysisId = await createAnalysisAttempt({
              supabaseAuthUserId: authUser.id,
              appUserId: requestBody.appUserId,
              isPaid: false,
              allowed: false,
              decisionReason,
              accessSource: "blocked",
              scanSource: requestBody.source.kind,
              attachmentCount: attachmentCountForRequest(requestBody),
              purchaseMode: requestBody.purchaseMode,
              categoryPreference: requestBody.categoryPreference,
              buildConfiguration: requestBody.buildConfiguration,
            });

            throw new RequestError(
              403,
              "entitlement_required",
              "An active CorkWise subscription is required to scan.",
              false,
            );
          }

          accessSource = "retry_credit";
          decisionReason = "retry_credit_available";
          retryCreditId = retryCredit.id;
        }
      }
    }

    analysisId = await createAnalysisAttempt({
      supabaseAuthUserId: authUser.id,
      appUserId: requestBody.appUserId,
      isPaid: entitlement.isPaid,
      allowed: true,
      decisionReason,
      accessSource,
      scanSource: requestBody.source.kind,
      attachmentCount: attachmentCountForRequest(requestBody),
      purchaseMode: requestBody.purchaseMode,
      categoryPreference: requestBody.categoryPreference,
      buildConfiguration: requestBody.buildConfiguration,
    });

    console.log("request validated", {
      purchaseMode: requestBody.purchaseMode,
      categoryPreference: requestBody.categoryPreference,
      pricingLocale: requestBody.pricingContext.localeIdentifier,
      currencyCode: requestBody.pricingContext.currencyCode,
      sourceKind: requestBody.source.kind,
      attachmentMimeTypes: requestBody.source.kind === "attachment"
        ? requestBody.source.attachments.map(
          (attachment) => attachment.mimeType,
        )
        : null,
      attachmentCount: requestBody.source.kind === "attachment"
        ? requestBody.source.attachments.length
        : null,
      attachmentBase64Lengths: requestBody.source.kind === "attachment"
        ? requestBody.source.attachments.map(
          (attachment) => attachment.base64Data.length,
        )
        : null,
      menuUrlHost: requestBody.source.kind === "url"
        ? new URL(requestBody.source.menuUrl).host
        : null,
      preferredStylesCount: requestBody.userPreferences.preferredStyles.length,
    });

    const provider = makeProvider();
    const providerResult = await provider.analyzeMenu(requestBody);
    const normalizedResult = normalizeScanResult(
      providerResult.payload,
      requestBody.purchaseMode,
    );

    // if (Deno.env.get("INCLUDE_DEBUG_INFO") === "true") {
    //   normalizedResult.debugInfo = {
    //     model: providerResult.model,
    //     apiDurationMilliseconds: providerResult.apiDurationMilliseconds,
    //     usage: providerResult.usage,
    //     totalCostUsd: providerResult.totalCostUsd,
    //   };
    // }

    let freeScanUsed = false;
    let retryCreditUsedId: string | null = null;

    if (accessSource === "free_scan") {
      const freeScanAllowance = await consumeFreeScan(
        requestBody.appUserId,
        FREE_SCAN_LIMIT,
      );

      if (freeScanAllowance.allowed === false) {
        throw new RequestError(
          403,
          "entitlement_required",
          "An active CorkWise subscription is required to scan.",
          false,
        );
      }

      freeScanUsed = true;
    } else if (accessSource === "retry_credit") {
      if (
        retryCreditId == null ||
        await consumeRetryCredit(retryCreditId) === false
      ) {
        throw new RequestError(
          403,
          "entitlement_required",
          "An active CorkWise subscription is required to scan.",
          false,
        );
      }

      retryCreditUsedId = retryCreditId;
    }

    normalizedResult.analysisId = analysisId;
    normalizedResult.modelVersion = providerResult.model;
    normalizedResult.promptVersion = PROMPT_VERSION;
    normalizedResult.freeScanUsed = freeScanUsed;

    await completeAnalysis({
      analysisId,
      provider: providerResult.provider,
      modelVersion: providerResult.model,
      success: true,
      estimatedCostUsd: providerResult.totalCostUsd,
      inputTokens: providerResult.usage?.promptTokenCount,
      outputTokens: providerResult.usage?.candidatesTokenCount,
      freeScanUsed,
      retryCreditUsedId: retryCreditUsedId ?? undefined,
      resultPayload: normalizedResult,
    });

    console.log("analysis complete", {
      recommendationCount: normalizedResult.recommendations.length,
      restaurantName: normalizedResult.restaurantName,
      currencyCode: normalizedResult.currencyCode,
      model: providerResult.model,
      apiDurationMilliseconds: providerResult.apiDurationMilliseconds,
      usage: providerResult.usage,
      totalCostUsd: providerResult.totalCostUsd,
    });

    if (Deno.env.get("LOG_FULL_RESPONSE") === "true") {
      console.log("full response", {
        providerResponse: providerResult,
      });
    }

    return Response.json(normalizedResult, {
      status: 200,
      headers: corsHeaders,
    });
  } catch (error) {
    if (analysisId != null) {
      await completeAnalysis({
        analysisId,
        success: false,
        errorCode: error instanceof RequestError
          ? error.responseBody.error
          : "analysis_failed",
      });
    }

    if (error instanceof RequestError) {
      return Response.json(error.responseBody, {
        status: error.status,
        headers: corsHeaders,
      });
    }

    console.error(
      "analyze-wine-menu failed:",
      error instanceof Error ? error.message : "unknown error",
    );

    return Response.json(
      {
        error: "analysis_failed",
        message: "Something went wrong while analyzing the wine list.",
        retrySuggested: true,
      } satisfies WineAnalysisErrorResponse,
      {
        status: 500,
        headers: corsHeaders,
      },
    );
  }
});

async function entitlementForRequest(
  requestBody: AnalyzeWineMenuRequest,
): Promise<EntitlementState> {
  if (
    ALLOW_DEBUG_ENTITLEMENT_BYPASS &&
    requestBody.buildConfiguration === "debug"
  ) {
    console.log("debug entitlement bypass enabled", {
      appUserId: requestBody.appUserId,
    });

    return {
      isPaid: true,
      appleOriginalTransactionId: null,
    };
  }

  return await checkEntitlement(requestBody.appUserId);
}

function attachmentCountForRequest(
  requestBody: AnalyzeWineMenuRequest,
): number {
  return requestBody.source.kind === "attachment"
    ? requestBody.source.attachments.length
    : 0;
}
