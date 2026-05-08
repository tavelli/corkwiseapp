import {RequestError, type PurchaseMode, type WineScanResult} from "./types.ts";

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
    currencyCode: currencyCodeOrDefault(candidate.currencyCode),
    summary,
    recommendations: normalizedRecommendations,
    categoryRecommendations: normalizedCategoryRecommendations,
    notes: normalizedNotes,
  };

  if (result.summary.headline.length === 0) {
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
  const wineName = requiredString(candidate.wineName);
  const extractedText = requiredString(candidate.extractedText);
  const producer = stringOrNull(candidate.producer);
  const region = stringOrNull(candidate.region);
  const varietal = stringOrNull(candidate.varietal);

  return {
    rank: positiveInt(candidate.rank) ?? index + 1,
    wineName,
    displayName: deriveDisplayName({
      producer,
      wineName,
      region,
      varietal,
      extractedText,
    }),
    extractedText,
    producer,
    region,
    vintage: vintageOrNull(candidate.vintage),
    varietal,
    menuPrice,
    estimatedRetail,
    estimatedMarkup: derivedMarkup?.value ?? null,
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
      .map((entry, index) =>
        normalizeRecommendation(entry, index, purchaseMode),
      ),
  };
}

function deriveDisplayName(input: {
  producer: string | null;
  wineName: string | null;
  region: string | null;
  varietal: string | null;
  extractedText: string;
}): string {
  const {producer, region, varietal, extractedText} = input;
  const wineName = distinctPart(input.wineName, [producer, varietal]);

  if (wineName != null) {
    return wineName;
  }

  if (varietal != null && region != null) {
    return joinDisplayParts(varietal, region);
  }

  if (varietal != null) {
    return varietal;
  }

  return distinctPart(extractedText, [producer]) ?? extractedText;
}

function joinDisplayParts(first: string, second: string): string {
  if (sameDisplayValue(first, second)) {
    return first;
  }

  return `${first} — ${second}`;
}

function distinctPart(
  value: string | null,
  existingParts: Array<string | null>,
): string | null {
  if (value == null) {
    return null;
  }

  const knownParts = existingParts.filter((part): part is string =>
    part != null && part.trim().length > 0
  );
  const trimmedValue = knownParts.reduce<string>(
    (candidate, part) =>
      candidate.replace(
        new RegExp(`\\b${escapeRegExp(part)}\\b`, "gi"),
        " ",
      ),
    value,
  ).trim().replace(/\s+/g, " ");

  if (trimmedValue.length === 0) {
    return null;
  }

  if (
    knownParts.some((part) =>
      sameDisplayValue(trimmedValue, part) ||
      includesDisplayValue(part, trimmedValue)
    )
  ) {
    return null;
  }

  return trimmedValue;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function sameDisplayValue(left: string, right: string): boolean {
  return normalizedDisplayValue(left) === normalizedDisplayValue(right);
}

function includesDisplayValue(container: string, value: string): boolean {
  const normalizedContainer = normalizedDisplayValue(container);
  const normalizedValue = normalizedDisplayValue(value);
  return normalizedContainer.includes(normalizedValue);
}

function normalizedDisplayValue(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/\p{Diacritic}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function deriveMarkup(input: {
  purchaseMode: PurchaseMode;
  menuPrice: number | null;
  estimatedRetail: number | null;
}): {value: number; display: string} | null {
  const {purchaseMode, menuPrice, estimatedRetail} = input;

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

function currencyCodeOrDefault(value: unknown): string {
  if (typeof value !== "string") {
    return "USD";
  }

  const currencyCode = value.trim().toUpperCase();
  return /^[A-Z]{3}$/.test(currencyCode) ? currencyCode : "USD";
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

function vintageOrNull(value: unknown): number | null {
  if (
    typeof value !== "number" ||
    Number.isInteger(value) === false ||
    value < 1800 ||
    value > 2100
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
