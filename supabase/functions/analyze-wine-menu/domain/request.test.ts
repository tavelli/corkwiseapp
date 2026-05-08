import {validateAnalyzeRequest} from "./request.ts";
import {RequestError} from "./types.ts";

Deno.test("validateAnalyzeRequest accepts menu URLs", () => {
  const request = validateAnalyzeRequest({
    appUserId: "7e95be64-3a08-4b6f-9943-61b9c1d15525",
    menuUrl: "https://example.com/wine-list",
    purchaseMode: "bottle",
    userPreferences: {
      preferredStyles: ["crisp whites"],
      favoriteVarietals: [],
      choiceStyle: "value",
    },
  });

  if (request.source.kind !== "url") {
    throw new Error("Expected URL source.");
  }

  if (request.categoryPreference !== "anything") {
    throw new Error("Expected default category preference.");
  }
});

Deno.test("validateAnalyzeRequest accepts build configuration metadata", () => {
  const request = validateAnalyzeRequest({
    appUserId: "7e95be64-3a08-4b6f-9943-61b9c1d15525",
    buildConfiguration: "testflight",
    menuUrl: "https://example.com/wine-list",
    purchaseMode: "bottle",
    userPreferences: {
      preferredStyles: ["crisp whites"],
      favoriteVarietals: [],
      choiceStyle: "value",
    },
  });

  if (request.buildConfiguration !== "testflight") {
    throw new Error("Expected build configuration to be preserved.");
  }
});

Deno.test("validateAnalyzeRequest rejects unsupported attachment types", () => {
  try {
    validateAnalyzeRequest({
      appUserId: "7e95be64-3a08-4b6f-9943-61b9c1d15525",
      attachment: {
        base64Data: "abc123",
        mimeType: "image/png",
      },
      purchaseMode: "bottle",
      userPreferences: {
        preferredStyles: ["reds"],
        favoriteVarietals: [],
        choiceStyle: "value",
      },
    });
  } catch (error) {
    if (
      error instanceof RequestError &&
      error.status === 400 &&
      error.responseBody.error === "invalid_request"
    ) {
      return;
    }

    throw error;
  }

  throw new Error("Expected unsupported MIME type to throw.");
});
