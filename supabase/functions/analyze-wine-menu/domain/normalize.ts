import {
  RequestError,
  type PurchaseMode,
  type WineScanResult,
} from "./types.ts";

export function normalizeScanResult(
  input: unknown,
  purchaseMode: PurchaseMode,
): WineScanResult {
  if (input == null || typeof input !== "object") {
    throw genericAnalysisFailure();
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
    throw genericAnalysisFailure();
  }

  return result;
}

function normalizeSummary(input: unknown): WineScanResult["summary"] {
  if (input == null || typeof input !== "object") {
    throw genericAnalysisFailure();
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
    throw genericAnalysisFailure();
  }

  const candidate = input as Record<string, unknown>;
  const menuPrice = numberOrNull(candidate.menuPrice);
  const estimatedRetail = numberOrNull(candidate.estimatedRetail);
  const derivedMarkup = deriveMarkup({
    purchaseMode,
    menuPrice,
    estimatedRetail,
  });

  return {
    rank: positiveInt(candidate.rank) ?? index + 1,
    wineName: requiredString(candidate.wineName),
    menuPrice,
    estimatedRetail,
    estimatedMarkup: derivedMarkup?.value ?? null,
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
    throw genericAnalysisFailure();
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

function deriveMarkup(input: {
  purchaseMode: PurchaseMode;
  menuPrice: number | null;
  estimatedRetail: number | null;
}): { value: number; display: string } | null {
  const {
    purchaseMode,
    menuPrice,
    estimatedRetail,
  } = input;

  if (
    menuPrice == null ||
    estimatedRetail == null ||
    menuPrice <= 0 ||
    estimatedRetail <= 0
  ) {
    return null;
  }

  const isGlassPour = purchaseMode === "glass";
  const costBasis = isGlassPour ? estimatedRetail / 5 : estimatedRetail;
  if (costBasis <= 0) {
    return null;
  }

  const value = roundToSingleDecimal(menuPrice / costBasis);
  const valueText = formatSingleDecimal(value);

  return {
    value,
    display: `~${valueText}x`,
  };
}

function genericAnalysisFailure(): RequestError {
  return new RequestError(
    502,
    "analysis_failed",
    "Something went wrong while analyzing the wine list.",
    true,
  );
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

  throw genericAnalysisFailure();
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
    throw genericAnalysisFailure();
  }

  return Math.min(10, Math.max(1, value));
}

function arrayOrEmpty(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}
