import { buildSystemPrompt } from "../domain/prompt.ts";
import { modelResponseSchema } from "../domain/schema.ts";
import {
  type AnalyzeWineMenuRequest,
  type ProviderAnalysisResult,
  RequestError,
  type TokenUsage,
  type WineModelProvider,
} from "../domain/types.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_TIMEOUT_MS = 45_000;

type ModelPricing = {
  inputPricePer1MTokens: number;
  outputPricePer1MTokens: number;
};

const GEMINI_PRICING_BY_MODEL: Record<string, ModelPricing> = {
  "gemini-3-flash-preview": {
    inputPricePer1MTokens: 0.5,
    outputPricePer1MTokens: 3.0,
  },
  "gemini-2.5-flash": {
    inputPricePer1MTokens: 0.3,
    outputPricePer1MTokens: 2.5,
  },
  "gemini-2.5-flash-lite": {
    inputPricePer1MTokens: 0.1,
    outputPricePer1MTokens: 0.4,
  },
};

export class GeminiProvider implements WineModelProvider {
  async analyzeMenu(
    requestBody: AnalyzeWineMenuRequest,
  ): Promise<ProviderAnalysisResult> {
    if (GEMINI_API_KEY == null || GEMINI_API_KEY.length === 0) {
      throw new RequestError(
        500,
        "analysis_failed",
        "The Gemini analysis service is not configured.",
        false,
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);
    const startedAt = Date.now();

    try {
      const requestPayload: Record<string, unknown> = {
        contents: [
          {
            role: "user",
            parts: [
              {
                text: buildSystemPrompt(requestBody),
              },
              menuInstructionPart(requestBody),
              ...menuSourceParts(requestBody),
            ],
          },
        ],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: modelResponseSchema,
        },
      };

      if (requestBody.source.kind === "url") {
        requestPayload.tools = [
          {
            url_context: {},
          },
        ];
      }

      console.log("calling Gemini", {
        model: GEMINI_MODEL,
        timeoutMs: GEMINI_TIMEOUT_MS,
        sourceKind: requestBody.source.kind,
      });

      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
        {
          method: "POST",
          headers: {
            "x-goog-api-key": GEMINI_API_KEY,
            "Content-Type": "application/json",
          },
          signal: controller.signal,
          body: JSON.stringify(requestPayload),
        },
      );

      if (response.ok === false) {
        const bodyText = await response.text();
        console.error(
          "Gemini request failed:",
          response.status,
          bodyText.slice(0, 400),
        );
        throw upstreamAnalysisFailure();
      }

      const payload = await response.json();
      const outputText = extractOutputText(payload);
      if (outputText == null) {
        console.error(
          "Gemini response missing candidate JSON",
          JSON.stringify(payload).slice(0, 500),
        );
        throw upstreamAnalysisFailure();
      }

      const usage = extractUsageMetadata(payload);
      try {
        return {
          payload: JSON.parse(outputText),
          provider: "gemini",
          model: GEMINI_MODEL,
          apiDurationMilliseconds: Date.now() - startedAt,
          usage,
          totalCostUsd: calculateTotalCostUsd(usage, GEMINI_MODEL),
        };
      } catch {
        console.error(
          "Gemini output was not valid JSON",
          outputText.slice(0, 500),
        );
        throw upstreamAnalysisFailure();
      }
    } catch (error) {
      if (error instanceof RequestError) {
        throw error;
      }

      if (error instanceof Error && error.name === "AbortError") {
        console.error(
          "Gemini request timed out after",
          GEMINI_TIMEOUT_MS,
          "ms",
        );
        throw new RequestError(
          504,
          "analysis_failed",
          "The wine analysis request timed out. Please try again.",
          true,
        );
      }

      console.error("Unexpected Gemini request error", error);
      throw upstreamAnalysisFailure();
    } finally {
      clearTimeout(timeout);
    }
  }
}

function extractUsageMetadata(
  payload: Record<string, unknown>,
): TokenUsage | undefined {
  const usageMetadata = payload.usageMetadata;
  if (usageMetadata == null || typeof usageMetadata !== "object") {
    return undefined;
  }

  const candidate = usageMetadata as Record<string, unknown>;
  const promptTokenCount = numberOrNull(candidate.promptTokenCount);
  const candidatesTokenCount = numberOrNull(candidate.candidatesTokenCount);
  const totalTokenCount = numberOrNull(candidate.totalTokenCount);

  if (
    promptTokenCount == null ||
    candidatesTokenCount == null ||
    totalTokenCount == null
  ) {
    return undefined;
  }

  return {
    promptTokenCount,
    candidatesTokenCount,
    totalTokenCount,
  };
}

function menuInstructionPart(
  requestBody: AnalyzeWineMenuRequest,
): Record<string, unknown> {
  if (requestBody.source.kind === "url") {
    return {
      text:
        "Analyze the restaurant wine list available at the provided URL and return only the requested JSON.",
    };
  }

  return {
    text: requestBody.source.attachments.length > 1
      ? "Analyze these ordered restaurant wine list page photos as one continuous wine list and return only the requested JSON."
      : "Analyze this restaurant wine list attachment and return only the requested JSON.",
  };
}

function menuSourceParts(
  requestBody: AnalyzeWineMenuRequest,
): Array<Record<string, unknown>> {
  if (requestBody.source.kind === "url") {
    return [{
      text: `Menu URL: ${requestBody.source.menuUrl}`,
    }];
  }

  const { attachments } = requestBody.source;
  if (attachments.length > 1) {
    return attachments.flatMap((attachment, index) => [
      {
        text: `Page ${index + 1} of ${attachments.length}:`,
      },
      attachmentPart(attachment),
    ]);
  }

  return [attachmentPart(attachments[0])];
}

function attachmentPart(
  attachment: {
    base64Data: string;
    mimeType: "image/jpeg" | "application/pdf";
  },
): Record<string, unknown> {
  return {
    inline_data: {
      mime_type: attachment.mimeType,
      data: attachment.base64Data,
    },
  };
}

function extractOutputText(payload: Record<string, unknown>): string | null {
  const candidates = payload.candidates;
  if (Array.isArray(candidates) === false) {
    return null;
  }

  for (const candidate of candidates) {
    const text = extractCandidateText(candidate);
    if (text != null) {
      return text;
    }
  }

  return null;
}

function extractCandidateText(candidate: unknown): string | null {
  if (candidate == null || typeof candidate !== "object") {
    return null;
  }

  const candidateRecord = candidate as Record<string, unknown>;
  const content = candidateRecord.content;
  if (content == null || typeof content !== "object") {
    return null;
  }

  const parts = (content as Record<string, unknown>).parts;
  if (Array.isArray(parts) === false) {
    return null;
  }

  for (const part of parts) {
    if (part == null || typeof part !== "object") {
      continue;
    }

    const text = (part as Record<string, unknown>).text;
    if (typeof text === "string" && text.trim().length > 0) {
      return text;
    }
  }

  return null;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function calculateTotalCostUsd(
  usage: TokenUsage | undefined,
  model: string,
): number | undefined {
  const pricing = GEMINI_PRICING_BY_MODEL[model];
  if (usage == null || pricing == null) {
    return undefined;
  }

  return (
    (usage.promptTokenCount * pricing.inputPricePer1MTokens +
      usage.candidatesTokenCount * pricing.outputPricePer1MTokens) /
    1_000_000
  );
}

function upstreamAnalysisFailure(): RequestError {
  return new RequestError(
    502,
    "analysis_failed",
    "Something went wrong while analyzing the wine list.",
    true,
  );
}
