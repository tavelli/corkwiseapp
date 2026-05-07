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
    },
    "bottle",
  );

  const [recommendation] = result.recommendations;
  if (recommendation.estimatedMarkup !== 2) {
    throw new Error(`Expected 2x markup, got ${recommendation.estimatedMarkup}`);
  }
});
