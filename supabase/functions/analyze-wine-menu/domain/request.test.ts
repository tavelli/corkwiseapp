import { validateAnalyzeRequest } from "./request.ts";
import { RequestError } from "./types.ts";

const appUserId = "7e95be64-3a08-4b6f-9943-61b9c1d15525";

function validPreferences() {
  return {
    preferredStyles: ["crisp whites"],
    favoriteVarietals: [],
    choiceStyle: "value",
  };
}

function validImage(filename = "wine-list-page.jpg") {
  return {
    base64Data: "abc123",
    mimeType: "image/jpeg",
    filename,
  };
}

function assertRequestError(
  action: () => unknown,
  status: number,
  errorCode: string,
) {
  try {
    action();
  } catch (error) {
    if (
      error instanceof RequestError &&
      error.status === status &&
      error.responseBody.error === errorCode
    ) {
      return;
    }

    throw error;
  }

  throw new Error(`Expected ${errorCode} to throw.`);
}

Deno.test("validateAnalyzeRequest accepts menu URLs", () => {
  const request = validateAnalyzeRequest({
    appUserId,
    menuUrl: "https://example.com/wine-list",
    purchaseMode: "bottle",
    userPreferences: validPreferences(),
  });

  if (request.source.kind !== "url") {
    throw new Error("Expected URL source.");
  }

  if (request.categoryPreference !== "anything") {
    throw new Error("Expected default category preference.");
  }
});

Deno.test("validateAnalyzeRequest accepts ordered JPEG attachments", () => {
  const request = validateAnalyzeRequest({
    appUserId,
    attachments: [
      validImage("page-1.jpg"),
      validImage("page-2.jpg"),
      validImage("page-3.jpg"),
    ],
    purchaseMode: "bottle",
    userPreferences: validPreferences(),
  });

  if (request.source.kind !== "attachment") {
    throw new Error("Expected attachment source.");
  }

  if (request.source.attachments.length !== 3) {
    throw new Error("Expected all attachments to be preserved.");
  }

  if (request.source.attachments[1].filename !== "page-2.jpg") {
    throw new Error("Expected attachment order to be preserved.");
  }
});

Deno.test("validateAnalyzeRequest accepts single PDF attachments", () => {
  const request = validateAnalyzeRequest({
    appUserId,
    attachments: [{
      base64Data: "abc123",
      mimeType: "application/pdf",
      filename: "wine-list.pdf",
    }],
    purchaseMode: "bottle",
    userPreferences: validPreferences(),
  });

  if (request.source.kind !== "attachment") {
    throw new Error("Expected attachment source.");
  }

  if (request.source.attachments[0].mimeType !== "application/pdf") {
    throw new Error("Expected PDF attachment.");
  }
});

Deno.test("validateAnalyzeRequest accepts build configuration metadata", () => {
  const request = validateAnalyzeRequest({
    appUserId,
    buildConfiguration: "testflight",
    menuUrl: "https://example.com/wine-list",
    purchaseMode: "bottle",
    userPreferences: validPreferences(),
  });

  if (request.buildConfiguration !== "testflight") {
    throw new Error("Expected build configuration to be preserved.");
  }
});

Deno.test("validateAnalyzeRequest accepts pricing context", () => {
  const request = validateAnalyzeRequest({
    appUserId,
    buildConfiguration: "testflight",
    menuUrl: "https://example.com/wine-list",
    purchaseMode: "bottle",
    pricingContext: {
      localeIdentifier: "en_GB",
      currencyCode: "gbp",
    },
    userPreferences: validPreferences(),
  });

  if (request.pricingContext.localeIdentifier !== "en_GB") {
    throw new Error("Expected locale identifier to be preserved.");
  }

  if (request.pricingContext.currencyCode !== "GBP") {
    throw new Error("Expected currency code to be normalized.");
  }
});

Deno.test("validateAnalyzeRequest defaults pricing context", () => {
  const request = validateAnalyzeRequest({
    appUserId,
    menuUrl: "https://example.com/wine-list",
    purchaseMode: "bottle",
    userPreferences: validPreferences(),
  });

  if (request.pricingContext.currencyCode !== "USD") {
    throw new Error("Expected default currency code.");
  }
});

Deno.test("validateAnalyzeRequest rejects malformed currency codes", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        menuUrl: "https://example.com/wine-list",
        purchaseMode: "bottle",
        pricingContext: {
          localeIdentifier: "en_GB",
          currencyCode: "GBP1",
        },
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});

Deno.test("validateAnalyzeRequest rejects unsupported attachment types", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        attachments: [{
          base64Data: "abc123",
          mimeType: "image/png",
        }],
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});

Deno.test("validateAnalyzeRequest rejects more than four attachments", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        attachments: [
          validImage("page-1.jpg"),
          validImage("page-2.jpg"),
          validImage("page-3.jpg"),
          validImage("page-4.jpg"),
          validImage("page-5.jpg"),
        ],
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    413,
    "image_too_large",
  );
});

Deno.test("validateAnalyzeRequest rejects multiple attachments containing PDFs", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        attachments: [
          validImage("page-1.jpg"),
          {
            base64Data: "abc123",
            mimeType: "application/pdf",
            filename: "wine-list.pdf",
          },
        ],
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});

Deno.test("validateAnalyzeRequest rejects legacy single attachment", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        attachment: validImage(),
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});

Deno.test("validateAnalyzeRequest rejects legacy imageBase64", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        imageBase64: "abc123",
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});

Deno.test("validateAnalyzeRequest rejects legacy URL alias", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        url: "https://example.com/wine-list",
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});

Deno.test("validateAnalyzeRequest rejects attachments and menuUrl together", () => {
  assertRequestError(
    () =>
      validateAnalyzeRequest({
        appUserId,
        attachments: [validImage()],
        menuUrl: "https://example.com/wine-list",
        purchaseMode: "bottle",
        userPreferences: validPreferences(),
      }),
    400,
    "invalid_request",
  );
});
