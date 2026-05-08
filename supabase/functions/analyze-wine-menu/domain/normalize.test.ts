import {normalizeScanResult} from "./normalize.ts";

Deno.test("normalizeScanResult derives bottle markup", () => {
  const result = normalizeScanResult(
    {
      summary: {
        headline: "Best values on the list",
      },
      recommendations: [
        {
          rank: 1,
          wineName: "Estate Pinot Noir",
          extractedText: "Producer Estate Pinot Noir",
          producer: "Producer",
          region: "Willamette Valley",
          vintage: 2021,
          varietal: "Pinot Noir",
          menuPrice: 72,
          estimatedRetail: 36,
          valueScore: 92,
          why: "Balanced markup and strong food versatility.",
        },
      ],
      currencyCode: "GBP",
    },
    "bottle",
  );

  if (result.currencyCode !== "GBP") {
    throw new Error(`Expected GBP currency, got ${result.currencyCode}`);
  }

  const [recommendation] = result.recommendations;
  if (recommendation.estimatedMarkup !== 2) {
    throw new Error(`Expected 2x markup, got ${recommendation.estimatedMarkup}`);
  }
});

Deno.test("normalizeScanResult defaults missing currency code", () => {
  const result = normalizeScanResult(
    {
      summary: {
        headline: "Best values on the list",
      },
      recommendations: [
        {
          rank: 1,
          wineName: "Estate Pinot Noir",
          extractedText: "Producer Estate Pinot Noir",
          producer: "Producer",
          region: "Willamette Valley",
          vintage: 2021,
          varietal: "Pinot Noir",
          menuPrice: 72,
          estimatedRetail: 36,
          valueScore: 92,
          why: "Balanced markup and strong food versatility.",
        },
      ],
    },
    "bottle",
  );

  if (result.currencyCode !== "USD") {
    throw new Error(`Expected USD default, got ${result.currencyCode}`);
  }
});
