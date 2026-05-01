import {RequestError, type AnalyzeWineMenuRequest} from "./types.ts";

export const MAX_REQUEST_BYTES = 8_000_000;
const MAX_IMAGE_BASE64_LENGTH = 7_000_000;

export function validateAnalyzeRequest(input: unknown): AnalyzeWineMenuRequest {
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
