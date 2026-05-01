import {buildSystemPrompt} from "../domain/prompt.ts";
import {modelResponseSchema} from "../domain/schema.ts";
import {
  RequestError,
  type AnalyzeWineMenuRequest,
  type ProviderAnalysisResult,
  type WineModelProvider,
} from "../domain/types.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o";
const OPENAI_REASONING_EFFORT = readOptionalEnv("OPENAI_REASONING_EFFORT");
const OPENAI_TEXT_VERBOSITY = readOptionalEnv("OPENAI_TEXT_VERBOSITY");
const OPENAI_TIMEOUT_MS = 45_000;

export class OpenAIProvider implements WineModelProvider {
  async analyzeMenu(
    requestBody: AnalyzeWineMenuRequest,
  ): Promise<ProviderAnalysisResult> {
    if (OPENAI_API_KEY == null || OPENAI_API_KEY.length === 0) {
      throw new RequestError(
        500,
        "analysis_failed",
        "The OpenAI analysis service is not configured.",
        false,
      );
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), OPENAI_TIMEOUT_MS);
    const startedAt = Date.now();

    try {
      console.log("calling OpenAI", {
        model: OPENAI_MODEL,
        reasoningEffort: OPENAI_REASONING_EFFORT ?? "disabled",
        textVerbosity: OPENAI_TEXT_VERBOSITY ?? "disabled",
        timeoutMs: OPENAI_TIMEOUT_MS,
      });

      const requestPayload: Record<string, unknown> = {
        model: OPENAI_MODEL,
        input: [
          {
            role: "system",
            content: [
              {
                type: "input_text",
                text: buildSystemPrompt(requestBody),
              },
            ],
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: "Analyze this restaurant wine list image and return only the requested JSON.",
              },
              {
                type: "input_image",
                image_url: `data:image/jpeg;base64,${requestBody.imageBase64}`,
                detail: "high",
              },
            ],
          },
        ],
        text: {
          format: {
            type: "json_schema",
            name: "wine_scan_result",
            strict: true,
            schema: modelResponseSchema,
          },
        },
      };

      if (OPENAI_REASONING_EFFORT != null) {
        requestPayload.reasoning = {
          effort: OPENAI_REASONING_EFFORT,
        };
      }

      if (OPENAI_TEXT_VERBOSITY != null) {
        const text = requestPayload.text as Record<string, unknown>;
        text.verbosity = OPENAI_TEXT_VERBOSITY;
      }

      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${OPENAI_API_KEY}`,
          "Content-Type": "application/json",
        },
        signal: controller.signal,
        body: JSON.stringify(requestPayload),
      });

      if (response.ok === false) {
        const bodyText = await response.text();
        console.error(
          "OpenAI request failed:",
          response.status,
          bodyText.slice(0, 400),
        );
        throw upstreamAnalysisFailure();
      }

      const payload = await response.json();
      const outputText = extractOutputText(payload);
      if (typeof outputText !== "string" || outputText.length === 0) {
        console.error(
          "OpenAI response missing final assistant JSON",
          JSON.stringify(payload).slice(0, 500),
        );
        throw upstreamAnalysisFailure();
      }

      try {
        return {
          payload: JSON.parse(outputText),
          provider: "openai",
          model: OPENAI_MODEL,
          apiDurationMilliseconds: Date.now() - startedAt,
        };
      } catch {
        console.error("OpenAI output was not valid JSON", outputText.slice(0, 500));
        throw upstreamAnalysisFailure();
      }
    } catch (error) {
      if (error instanceof RequestError) {
        throw error;
      }

      if (error instanceof Error && error.name === "AbortError") {
        console.error("OpenAI request timed out after", OPENAI_TIMEOUT_MS, "ms");
        throw new RequestError(
          504,
          "analysis_failed",
          "The wine analysis request timed out. Please try again.",
          true,
        );
      }

      console.error("Unexpected OpenAI request error", error);
      throw upstreamAnalysisFailure();
    } finally {
      clearTimeout(timeout);
    }
  }
}

function extractOutputText(payload: Record<string, unknown>): string | null {
  if (
    typeof payload.output_text === "string" &&
    payload.output_text.length > 0
  ) {
    return payload.output_text;
  }

  if (Array.isArray(payload.output)) {
    for (const item of payload.output) {
      const candidateText = extractAssistantMessageText(item);
      if (candidateText != null) {
        return candidateText;
      }
    }
  }

  return null;
}

function extractAssistantMessageText(item: unknown): string | null {
  if (item == null || typeof item !== "object") {
    return null;
  }

  const candidateItem = item as Record<string, unknown>;
  if (candidateItem.type !== "message" || candidateItem.role !== "assistant") {
    return null;
  }

  const content = candidateItem.content;
  if (Array.isArray(content) === false) {
    return null;
  }

  for (const contentPart of content) {
    const candidateText = extractTextContent(contentPart);
    if (candidateText != null) {
      return candidateText;
    }
  }

  return null;
}

function extractTextContent(contentPart: unknown): string | null {
  if (contentPart == null || typeof contentPart !== "object") {
    return null;
  }

  const candidate = contentPart as Record<string, unknown>;
  const partType = stringOrNull(candidate.type);
  if (partType != null && partType !== "output_text" && partType !== "text") {
    return null;
  }

  if (typeof candidate.text === "string" && candidate.text.trim().length > 0) {
    return candidate.text;
  }

  const value = stringOrNull(candidate.value);
  if (value != null) {
    return value;
  }

  return null;
}

function readOptionalEnv(name: string): string | null {
  const value = Deno.env.get(name)?.trim();
  if (value == null || value.length === 0) {
    return null;
  }

  const normalized = value.toLowerCase();
  if (normalized === "off" || normalized === "none" || normalized === "false") {
    return null;
  }

  return value;
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function upstreamAnalysisFailure(): RequestError {
  return new RequestError(
    502,
    "analysis_failed",
    "Something went wrong while analyzing the wine list.",
    true,
  );
}
