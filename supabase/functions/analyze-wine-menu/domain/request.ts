import {
  RequestError,
  type AnalyzeWineMenuAttachment,
  type AnalyzeWineMenuRequest,
} from "./types.ts";

export const MAX_REQUEST_BYTES = 8_000_000;
const MAX_ATTACHMENT_BASE64_LENGTH = 7_000_000;

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
  const attachment = attachmentOrNull(candidate.attachment) ??
    legacyImageAttachment(candidate.imageBase64);
  const purchaseMode = stringOrNull(candidate.purchaseMode);
  const userPreferences = candidate.userPreferences;

  if (attachment == null || attachment.base64Data.length === 0) {
    throw new RequestError(
      400,
      "invalid_request",
      "An image or PDF file is required.",
      false,
    );
  }

  if (attachment.base64Data.length > MAX_ATTACHMENT_BASE64_LENGTH) {
    throw new RequestError(
      413,
      "image_too_large",
      "The selected file is too large. Please try again with a smaller image or PDF.",
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
  const favoriteVarietals = stringArrayOrNull(preferences.favoriteVarietals) ?? [];

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
    attachment,
    purchaseMode,
    userPreferences: {
      experienceLevel,
      preferredStyles,
      favoriteVarietals,
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

function attachmentOrNull(value: unknown): AnalyzeWineMenuAttachment | null {
  if (value == null || typeof value !== "object") {
    return null;
  }

  const candidate = value as Record<string, unknown>;
  const base64Data = stringOrNull(candidate.base64Data);
  const mimeType = stringOrNull(candidate.mimeType);
  const filename = optionalStringOrNull(candidate.filename);

  if (base64Data == null || mimeType == null) {
    return null;
  }

  if (mimeType !== "image/jpeg" && mimeType !== "application/pdf") {
    throw new RequestError(
      400,
      "invalid_request",
      "attachment.mimeType must be either 'image/jpeg' or 'application/pdf'.",
      false,
    );
  }

  return {
    base64Data,
    mimeType,
    filename,
  };
}

function legacyImageAttachment(value: unknown): AnalyzeWineMenuAttachment | null {
  const imageBase64 = stringOrNull(value);
  if (imageBase64 == null) {
    return null;
  }

  return {
    base64Data: imageBase64,
    mimeType: "image/jpeg",
    filename: null,
  };
}

function optionalStringOrNull(value: unknown): string | null {
  if (value == null) {
    return null;
  }

  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
