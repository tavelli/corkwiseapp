import {
  RequestError,
  type AnalyzeWineMenuAttachment,
  type AnalyzeWineMenuRequest,
} from "./types.ts";

export const MAX_REQUEST_BYTES = 8_000_000;
const MAX_ATTACHMENT_BASE64_LENGTH = 7_000_000;
const MAX_MENU_URL_LENGTH = 2_000;

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
  const appUserId = stringOrNull(candidate.appUserId);
  const buildConfiguration = buildConfigurationOrNull(candidate.buildConfiguration);
  const attachment = attachmentOrNull(candidate.attachment) ??
    legacyImageAttachment(candidate.imageBase64);
  const menuUrl = menuUrlOrNull(candidate.menuUrl) ?? menuUrlOrNull(candidate.url);
  const purchaseMode = stringOrNull(candidate.purchaseMode);
  const categoryPreference = stringOrNull(candidate.categoryPreference) ??
    "anything";
  const userPreferences = candidate.userPreferences;

  if (
    (attachment == null || attachment.base64Data.length === 0) &&
    menuUrl == null
  ) {
    throw new RequestError(
      400,
      "invalid_request",
      "An image, PDF, or menu URL is required.",
      false,
    );
  }

  if (appUserId == null || isUUID(appUserId) === false) {
    throw new RequestError(
      400,
      "invalid_request",
      "appUserId must be a valid UUID.",
      false,
    );
  }

  if (
    attachment != null &&
    attachment.base64Data.length > MAX_ATTACHMENT_BASE64_LENGTH
  ) {
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

  if (
    categoryPreference !== "anything" &&
    categoryPreference !== "reds" &&
    categoryPreference !== "whites" &&
    categoryPreference !== "sparkling"
  ) {
    throw new RequestError(
      400,
      "invalid_request",
      "categoryPreference must be 'anything', 'reds', 'whites', or 'sparkling'.",
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
  const choiceStyle = stringOrNull(preferences.choiceStyle);
  const tone = stringOrNull(preferences.tone) ?? "standard";
  const preferredStyles = stringArrayOrNull(preferences.preferredStyles);
  const favoriteVarietals = stringArrayOrNull(preferences.favoriteVarietals) ?? [];

  if (
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
    appUserId,
    ...(buildConfiguration == null ? {} : {buildConfiguration}),
    source: menuUrl == null
      ? {
        kind: "attachment",
        attachment: attachment!,
      }
      : {
        kind: "url",
        menuUrl,
      },
    purchaseMode,
    categoryPreference,
    userPreferences: {
      preferredStyles,
      favoriteVarietals,
      choiceStyle,
      tone,
    },
  };
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
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

function buildConfigurationOrNull(
  value: unknown,
): AnalyzeWineMenuRequest["buildConfiguration"] | null {
  const buildConfiguration = stringOrNull(value);
  if (buildConfiguration == null) {
    return null;
  }

  if (
    buildConfiguration !== "debug" &&
    buildConfiguration !== "testflight" &&
    buildConfiguration !== "appstore" &&
    buildConfiguration !== "release_unknown"
  ) {
    throw new RequestError(
      400,
      "invalid_request",
      "buildConfiguration is invalid.",
      false,
    );
  }

  return buildConfiguration;
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

function menuUrlOrNull(value: unknown): string | null {
  const menuUrl = stringOrNull(value);
  if (menuUrl == null) {
    return null;
  }

  if (menuUrl.length > MAX_MENU_URL_LENGTH) {
    throw new RequestError(
      400,
      "invalid_request",
      "menuUrl is too long.",
      false,
    );
  }

  let parsedUrl: URL;
  try {
    parsedUrl = new URL(menuUrl);
  } catch {
    throw new RequestError(
      400,
      "invalid_request",
      "menuUrl must be a valid URL.",
      false,
    );
  }

  if (parsedUrl.protocol !== "https:" && parsedUrl.protocol !== "http:") {
    throw new RequestError(
      400,
      "invalid_request",
      "menuUrl must use http or https.",
      false,
    );
  }

  return parsedUrl.href;
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
