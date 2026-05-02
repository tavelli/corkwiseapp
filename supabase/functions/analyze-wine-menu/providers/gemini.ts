import {buildSystemPrompt} from "../domain/prompt.ts";
import {modelResponseSchema} from "../domain/schema.ts";
import {
  RequestError,
  type AnalyzeWineMenuRequest,
  type ProviderAnalysisResult,
  type WineModelProvider,
} from "../domain/types.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY");
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_TIMEOUT_MS = 45_000;

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
      console.log("calling Gemini", {
        model: GEMINI_MODEL,
        timeoutMs: GEMINI_TIMEOUT_MS,
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
          body: JSON.stringify({
            contents: [
              {
                role: "user",
                parts: [
                  {
                    text: buildSystemPrompt(requestBody),
                  },
                  {
                    text: "Analyze this restaurant wine list attachment and return only the requested JSON.",
                  },
                  attachmentPart(requestBody),
                ],
              },
            ],
            generationConfig: {
              responseMimeType: "application/json",
              responseJsonSchema: modelResponseSchema,
            },
          }),
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

      try {
        return {
          payload: JSON.parse(outputText),
          provider: "gemini",
          model: GEMINI_MODEL,
          apiDurationMilliseconds: Date.now() - startedAt,
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

function attachmentPart(
  requestBody: AnalyzeWineMenuRequest,
): Record<string, unknown> {
  return {
    inline_data: {
      mime_type: requestBody.attachment.mimeType,
      data: requestBody.attachment.base64Data,
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

function upstreamAnalysisFailure(): RequestError {
  return new RequestError(
    502,
    "analysis_failed",
    "Something went wrong while analyzing the wine list.",
    true,
  );
}
