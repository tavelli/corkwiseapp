import type {AnalyzeWineMenuRequest} from "./types.ts";

const SYSTEM_PROMPT_TEMPLATE = await Deno.readTextFile(
  new URL("./prompt.xml", import.meta.url),
);

export const PROMPT_VERSION = "2026-06-17";

export function buildSystemPrompt(
  requestBody: AnalyzeWineMenuRequest,
  currentDate: Date = new Date(),
): string {
  const {isoDate, year} = promptDateParts(currentDate);

  return renderPrompt(SYSTEM_PROMPT_TEMPLATE, {
    categoryPreference: requestBody.categoryPreference,
    currencyCode: requestBody.pricingContext.currencyCode,
    currentDate: isoDate,
    currentYear: String(year),
    favoriteVarietals:
      requestBody.userPreferences.favoriteVarietals.join(", ") || "none",
    localeIdentifier: requestBody.pricingContext.localeIdentifier,
    preferredStyles:
      requestBody.userPreferences.preferredStyles.join(", ") || "none",
    purchaseMode: requestBody.purchaseMode,
  });
}

function promptDateParts(date: Date): {isoDate: string; year: number} {
  const isoDate = date.toISOString().slice(0, 10);
  const year = date.getUTCFullYear();

  return {isoDate, year};
}

function renderPrompt(
  template: string,
  values: Record<string, string>,
): string {
  return template.replace(/\{\{(\w+)\}\}/g, (match, key: string) => {
    const value = values[key];

    if (value == null) {
      throw new Error(`Missing system prompt value for ${match}`);
    }

    return value;
  });
}
