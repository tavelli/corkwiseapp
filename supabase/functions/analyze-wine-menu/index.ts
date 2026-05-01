const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o";
const OPENAI_REASONING_EFFORT = readOptionalEnv("OPENAI_REASONING_EFFORT");
const OPENAI_TEXT_VERBOSITY = readOptionalEnv("OPENAI_TEXT_VERBOSITY");
const MAX_REQUEST_BYTES = 8_000_000;
const MAX_IMAGE_BASE64_LENGTH = 7_000_000;
const OPENAI_TIMEOUT_MS = 45_000;

type PurchaseMode = "glass" | "bottle";

type AnalyzeWineMenuRequest = {
  imageBase64: string;
  purchaseMode: PurchaseMode;
  userPreferences: {
    experienceLevel: string;
    preferredStyles: string[];
    choiceStyle: string;
  };
};

type WineAnalysisErrorResponse = {
  error: string;
  message: string;
  retrySuggested: boolean;
};

type WineScanResult = {
  restaurantName: string | null;
  summary: {
    headline: string;
    bestPickName: string;
    bestPickScore: number;
    bestPickWhy: string;
  };
  recommendations: Array<{
    rank: number;
    wineName: string;
    menuPrice: number | null;
    estimatedRetailLow: number | null;
    estimatedRetailHigh: number | null;
    estimatedMarkupLow: number | null;
    estimatedMarkupHigh: number | null;
    estimatedMarkupDisplay: string | null;
    valueScore: number;
    why: string;
  }>;
  categoryRecommendations: Array<{
    key: string;
    title: string;
    recommendations: Array<{
      rank: number;
      wineName: string;
      menuPrice: number | null;
      estimatedRetailLow: number | null;
      estimatedRetailHigh: number | null;
      estimatedMarkupLow: number | null;
      estimatedMarkupHigh: number | null;
      estimatedMarkupDisplay: string | null;
      valueScore: number;
      why: string;
    }>;
  }>;
  notes: string[];
  debugInfo?: {
    model: string;
    apiDurationMilliseconds: number;
  };
};

class RequestError extends Error {
  status: number;
  responseBody: WineAnalysisErrorResponse;

  constructor(
    status: number,
    error: string,
    message: string,
    retrySuggested: boolean,
  ) {
    super(message);
    this.status = status;
    this.responseBody = {error, message, retrySuggested};
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {headers: corsHeaders});
  }

  try {
    console.log("analyze-wine-menu invoked", new Date().toISOString());

    if (req.method !== "POST") {
      throw new RequestError(
        405,
        "invalid_request",
        "Only POST requests are supported.",
        false,
      );
    }

    if (OPENAI_API_KEY == null || OPENAI_API_KEY.length === 0) {
      throw new RequestError(
        500,
        "analysis_failed",
        "The analysis service is not configured.",
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
        "The selected image is too large. Please try again with a smaller image.",
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

    const requestBody = validateAnalyzeRequest(parsedBody);
    console.log("request validated", {
      purchaseMode: requestBody.purchaseMode,
      imageBase64Length: requestBody.imageBase64.length,
      preferredStylesCount: requestBody.userPreferences.preferredStyles.length,
    });
    const openAIResult = await analyzeWineMenu(requestBody);
    const normalizedResult = normalizeScanResult(
      openAIResult.payload,
      requestBody.purchaseMode,
    );
    normalizedResult.debugInfo = {
      model: openAIResult.model,
      apiDurationMilliseconds: openAIResult.apiDurationMilliseconds,
    };
    console.log("analysis complete", {
      recommendationCount: normalizedResult.recommendations.length,
      restaurantName: normalizedResult.restaurantName,
    });

    return Response.json(normalizedResult, {
      status: 200,
      headers: corsHeaders,
    });
  } catch (error) {
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

function validateAnalyzeRequest(input: unknown): AnalyzeWineMenuRequest {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      400,
      "invalid_request",
      "Request body must be a JSON object.",
      false,
    );
  }

  const candidate = input as Record<string, unknown>;
  const imageBase64 = stringOrNull(candidate.imageBase64);
  const purchaseMode = stringOrNull(candidate.purchaseMode);
  const userPreferences = candidate.userPreferences;

  if (imageBase64 == null || imageBase64.length === 0) {
    throw new RequestError(
      400,
      "invalid_request",
      "An image is required.",
      false,
    );
  }

  if (imageBase64.length > MAX_IMAGE_BASE64_LENGTH) {
    throw new RequestError(
      413,
      "image_too_large",
      "The selected image is too large. Please try again with a smaller image.",
      true,
    );
  }

  if (purchaseMode !== "glass" && purchaseMode !== "bottle") {
    throw new RequestError(
      400,
      "invalid_request",
      "purchaseMode must be either 'glass' or 'bottle'.",
      false,
    );
  }

  if (userPreferences == null || typeof userPreferences !== "object") {
    throw new RequestError(
      400,
      "invalid_request",
      "userPreferences is required.",
      false,
    );
  }

  const preferences = userPreferences as Record<string, unknown>;
  const experienceLevel = stringOrNull(preferences.experienceLevel);
  const choiceStyle = stringOrNull(preferences.choiceStyle);
  const preferredStyles = stringArrayOrNull(preferences.preferredStyles);

  if (
    experienceLevel == null ||
    choiceStyle == null ||
    preferredStyles == null
  ) {
    throw new RequestError(
      400,
      "invalid_request",
      "userPreferences is incomplete.",
      false,
    );
  }

  return {
    imageBase64,
    purchaseMode,
    userPreferences: {
      experienceLevel,
      preferredStyles,
      choiceStyle,
    },
  };
}

async function analyzeWineMenu(
  requestBody: AnalyzeWineMenuRequest,
): Promise<{
  payload: unknown;
  model: string;
  apiDurationMilliseconds: number;
}> {
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
          schema: openAIResponseSchema,
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
      throw new RequestError(
        502,
        "analysis_failed",
        "Something went wrong while analyzing the wine list.",
        true,
      );
    }

    const payload = await response.json();
    console.log("OpenAI response received");

    const outputText = extractOutputText(payload);
    if (typeof outputText !== "string" || outputText.length === 0) {
      console.error(
        "OpenAI response missing final assistant JSON",
        JSON.stringify(payload).slice(0, 500),
      );
      throw new RequestError(
        502,
        "analysis_failed",
        "Something went wrong while analyzing the wine list.",
        true,
      );
    }

    try {
      return {
        payload: JSON.parse(outputText),
        model: OPENAI_MODEL,
        apiDurationMilliseconds: Date.now() - startedAt,
      };
    } catch {
      console.error(
        "OpenAI output was not valid JSON",
        outputText.slice(0, 500),
      );
      throw new RequestError(
        502,
        "analysis_failed",
        "Something went wrong while analyzing the wine list.",
        true,
      );
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
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  } finally {
    clearTimeout(timeout);
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

function normalizeScanResult(
  input: unknown,
  purchaseMode: PurchaseMode,
): WineScanResult {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }

  const candidate = input as Record<string, unknown>;
  const recommendations = arrayOrEmpty(candidate.recommendations);

  if (recommendations.length === 0) {
    throw new RequestError(
      422,
      "no_wines_detected",
      "We couldn’t identify enough wine listings to generate recommendations.",
      true,
    );
  }

  const normalizedRecommendations = recommendations.map((entry, index) =>
    normalizeRecommendation(entry, index, purchaseMode),
  );
  const normalizedCategoryRecommendations = arrayOrEmpty(
    candidate.categoryRecommendations,
  ).map((entry) => normalizeCategorySection(entry, purchaseMode));
  const normalizedNotes = stringArrayOrEmpty(candidate.notes);
  const summary = normalizeSummary(candidate.summary);

  const result: WineScanResult = {
    restaurantName: stringOrNull(candidate.restaurantName),
    summary,
    recommendations: normalizedRecommendations,
    categoryRecommendations: normalizedCategoryRecommendations,
    notes: normalizedNotes,
  };

  if (
    result.summary.bestPickName.length === 0 ||
    result.summary.headline.length === 0
  ) {
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }

  return result;
}

function normalizeSummary(input: unknown): WineScanResult["summary"] {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }

  const candidate = input as Record<string, unknown>;
  return {
    headline: requiredString(candidate.headline),
    bestPickName: requiredString(candidate.bestPickName),
    bestPickScore: boundedScore(candidate.bestPickScore),
    bestPickWhy: requiredString(candidate.bestPickWhy),
  };
}

function normalizeRecommendation(
  input: unknown,
  index: number,
  purchaseMode: PurchaseMode,
): WineScanResult["recommendations"][number] {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }

  const candidate = input as Record<string, unknown>;
  const menuPrice = numberOrNull(candidate.menuPrice);
  const estimatedRetailLow = numberOrNull(candidate.estimatedRetailLow);
  const estimatedRetailHigh = numberOrNull(candidate.estimatedRetailHigh);
  const derivedMarkup = deriveMarkupRange({
    purchaseMode,
    menuPrice,
    estimatedRetailLow,
    estimatedRetailHigh,
  });

  return {
    rank: positiveInt(candidate.rank) ?? index + 1,
    wineName: requiredString(candidate.wineName),
    menuPrice,
    estimatedRetailLow,
    estimatedRetailHigh,
    estimatedMarkupLow: derivedMarkup?.low ?? null,
    estimatedMarkupHigh: derivedMarkup?.high ?? null,
    estimatedMarkupDisplay: derivedMarkup?.display ?? null,
    valueScore: boundedScore(candidate.valueScore),
    why: requiredString(candidate.why),
  };
}

function normalizeCategorySection(
  input: unknown,
  purchaseMode: PurchaseMode,
): WineScanResult["categoryRecommendations"][number] {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }

  const candidate = input as Record<string, unknown>;
  return {
    key: requiredString(candidate.key),
    title: requiredString(candidate.title),
    recommendations: arrayOrEmpty(candidate.recommendations)
      .slice(0, 2)
      .map((entry, index) => normalizeRecommendation(entry, index, purchaseMode)),
  };
}

function buildSystemPrompt(requestBody: AnalyzeWineMenuRequest): string {
  return [
    "You are Corkwise, a personal restaurant wine list advisor.",
    "",
    "Analyze the provided restaurant wine list image. Extract visible wines and prices as accurately as possible. Then rank the best recommendations based on value, producer reputation, category pricing, estimated restaurant markup, age/scarcity, and fit for the user's preferences.",
    "",
    "Do not invent wines, vintages, prices, restaurants, or producers that are not visible or reasonably inferable from the image.",
    "If text is unclear, say so in the notes.",
    "If the image is too blurry or does not contain enough wine information, still return the schema but leave recommendations empty and explain the issue in notes.",
    "",
    `The user is ordering by: ${requestBody.purchaseMode}.`,
    "The purchase mode affects recommendations only. It should not limit extraction.",
    "If the user selected glass, prioritize by-the-glass options when visible.",
    "If the user selected bottle, prioritize bottle options when visible.",
    "Always estimate retail as the price of a full bottle, even when the user selected glass.",
    "When a recommendation is for a glass pour, estimate restaurant markup using one-fifth of the bottle retail cost as the cost basis for that glass.",
    "For glass pours, the menu price should still be the by-the-glass menu price, while estimatedRetailLow, estimatedRetailHigh, and estimatedRetailDisplay should represent the full bottle retail estimate.",
    "Do not calculate or return markup fields yourself. The system will derive markup from menu price and retail bottle estimates.",
    "",
    "User preferences:",
    `- Experience level: ${requestBody.userPreferences.experienceLevel}`,
    `- Preferred styles: ${requestBody.userPreferences.preferredStyles.join(", ") || "none"}`,
    `- Choice style: ${requestBody.userPreferences.choiceStyle}`,
    "",
    "Scoring method:",
    "Value score = 1-10 based on estimated retail price vs. menu price, producer reputation, category inflation, age/scarcity, and whether the wine gives the user something meaningfully better than cheaper alternatives on the same list.",
    "",
    "The value score is not just markup math.",
    "Return 3-5 'Best Overall Picks' in recommendations. These are the smartest overall choices on the list.",
    "Then separately return 1-2 recommendations for each relevant category in categoryRecommendations.",
    "Use these category keys when relevant: best_value, best_splurge, safest_choice, most_interesting_pick.",
    "Do not include best_overall in categoryRecommendations because the main recommendations array already covers that.",
    "The category-specific picks can overlap with the best overall picks if they genuinely fit both.",
    "Return JSON only and adhere exactly to the provided schema.",
  ].join("\n");
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

function deriveMarkupRange(input: {
  purchaseMode: PurchaseMode;
  menuPrice: number | null;
  estimatedRetailLow: number | null;
  estimatedRetailHigh: number | null;
}): { low: number; high: number; display: string } | null {
  const {
    purchaseMode,
    menuPrice,
    estimatedRetailLow,
    estimatedRetailHigh,
  } = input;

  if (
    menuPrice == null ||
    estimatedRetailLow == null ||
    estimatedRetailHigh == null ||
    menuPrice <= 0 ||
    estimatedRetailLow <= 0 ||
    estimatedRetailHigh <= 0
  ) {
    return null;
  }

  const isGlassPour = purchaseMode === "glass";

  const lowCostBasis = isGlassPour ? estimatedRetailHigh / 5 : estimatedRetailHigh;
  const highCostBasis = isGlassPour ? estimatedRetailLow / 5 : estimatedRetailLow;
  if (lowCostBasis <= 0 || highCostBasis <= 0) {
    return null;
  }

  const low = roundToSingleDecimal(menuPrice / lowCostBasis);
  const high = roundToSingleDecimal(menuPrice / highCostBasis);
  const lowText = formatSingleDecimal(low);
  const highText = formatSingleDecimal(high);

  if (Math.abs(low - high) < 0.05) {
    return {
      low,
      high,
      display: `${lowText}x`,
    };
  }

  return {
    low,
    high,
    display: `~${lowText}x-${highText}x`,
  };
}

function roundToSingleDecimal(value: number): number {
  return Math.round(value * 10) / 10;
}

function formatSingleDecimal(value: number): string {
  return value.toFixed(1);
}

function requiredString(value: unknown): string {
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }

  throw new RequestError(
    502,
    "analysis_failed",
    "Something went wrong while analyzing the wine list.",
    true,
  );
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function stringArrayOrNull(value: unknown): string[] | null {
  if (Array.isArray(value) === false) {
    return null;
  }

  const strings = value
    .filter((entry): entry is string => typeof entry === "string")
    .map((entry) => entry.trim())
    .filter(Boolean);
  return strings.length === value.length ? strings : null;
}

function stringArrayOrEmpty(value: unknown): string[] {
  return stringArrayOrNull(value) ?? [];
}

function numberOrNull(value: unknown): number | null {
  if (typeof value !== "number" || Number.isFinite(value) === false) {
    return null;
  }

  return value;
}

function positiveInt(value: unknown): number | null {
  if (
    typeof value !== "number" ||
    Number.isInteger(value) === false ||
    value < 1
  ) {
    return null;
  }

  return value;
}

function boundedScore(value: unknown): number {
  if (typeof value !== "number" || Number.isFinite(value) === false) {
    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }

  return Math.min(10, Math.max(1, value));
}

function arrayOrEmpty(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

const openAIResponseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    restaurantName: {type: ["string", "null"]},
    summary: {
      type: "object",
      additionalProperties: false,
      properties: {
        headline: {type: "string"},
        bestPickName: {type: "string"},
        bestPickScore: {type: "number"},
        bestPickWhy: {type: "string"},
      },
      required: ["headline", "bestPickName", "bestPickScore", "bestPickWhy"],
    },
    recommendations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          rank: {type: "integer"},
          wineName: {type: "string"},
          menuPrice: {type: ["number", "null"]},
          estimatedRetailLow: {type: ["number", "null"]},
          estimatedRetailHigh: {type: ["number", "null"]},
          valueScore: {type: "number"},
          why: {type: "string"},
        },
        required: [
          "rank",
          "wineName",
          "menuPrice",
          "estimatedRetailLow",
          "estimatedRetailHigh",
          "valueScore",
          "why",
        ],
      },
    },
    categoryRecommendations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          key: {type: "string"},
          title: {type: "string"},
          recommendations: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                rank: {type: "integer"},
                wineName: {type: "string"},
                menuPrice: {type: ["number", "null"]},
                estimatedRetailLow: {type: ["number", "null"]},
                estimatedRetailHigh: {type: ["number", "null"]},
                valueScore: {type: "number"},
                why: {type: "string"},
              },
              required: [
                "rank",
                "wineName",
                "menuPrice",
                "estimatedRetailLow",
                "estimatedRetailHigh",
                "valueScore",
                "why",
              ],
            },
          },
        },
        required: ["key", "title", "recommendations"],
      },
    },
    notes: {
      type: "array",
      items: {type: "string"},
    },
  },
  required: [
    "restaurantName",
    "summary",
    "recommendations",
    "categoryRecommendations",
    "notes",
  ],
} as const;
