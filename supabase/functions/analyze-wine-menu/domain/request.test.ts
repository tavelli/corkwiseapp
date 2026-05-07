import {validateAnalyzeRequest} from "./request.ts";
import {RequestError} from "./types.ts";

Deno.test("validateAnalyzeRequest accepts menu URLs", () => {
  const request = validateAnalyzeRequest({
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

Deno.test("validateAnalyzeRequest rejects unsupported attachment types", () => {
  try {
    validateAnalyzeRequest({
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
