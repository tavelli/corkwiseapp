import { buildSystemPrompt } from "./prompt.ts";
import type { AnalyzeWineMenuRequest } from "./types.ts";

Deno.test("buildSystemPrompt renders xml prompt values", () => {
  const request: AnalyzeWineMenuRequest = {
    appUserId: "test-user",
    categoryPreference: "reds",
    pricingContext: {
      currencyCode: "USD",
      localeIdentifier: "en_US",
    },
    purchaseMode: "glass",
    source: {
      kind: "url",
      menuUrl: "https://example.com/menu",
    },
    userPreferences: {
      choiceStyle: "value",
      favoriteVarietals: ["Pinot Noir", "Syrah"],
      preferredStyles: ["earthy reds"],
      tone: "standard",
    },
  };

  const prompt = buildSystemPrompt(request, new Date("2026-05-22T12:00:00Z"));

  assertIncludes(prompt, "<role>");
  assertIncludes(prompt, "The current date is 2026-05-22.");
  assertIncludes(prompt, "The user is ordering by: glass.");
  assertIncludes(prompt, "using locale en_US and currency USD");
  assertIncludes(prompt, "- Preferred styles: earthy reds");
  assertIncludes(prompt, "- Favorite varietals: Pinot Noir, Syrah");
  assertIncludes(prompt, "- Category Preference: reds");
  assertIncludes(prompt, "<notes_rules>");
  assertIncludes(prompt, "<weak_spots>");
  assertIncludes(prompt, "Populate the weakSpots array");
  // assertIncludes(prompt, "Use the notes array only for small extraction caveats");
  assertIncludes(
    prompt,
    "Do not contradict, discount, or undermine any root-level recommendation's selection logic",
  );

  if (/\{\{\w+\}\}/.test(prompt)) {
    throw new Error("Expected all prompt placeholders to be rendered.");
  }
});

function assertIncludes(value: string, expected: string) {
  if (!value.includes(expected)) {
    throw new Error(`Expected prompt to include: ${expected}`);
  }
}
