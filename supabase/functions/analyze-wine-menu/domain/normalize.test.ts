import { normalizeScanResult } from "./normalize.ts";

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
          menuPriceUnit: "bottle",
          estimatedRetail: 36,
          scores: {
            markupFairness: 6,
            producerPedigree: 5,
            menuStandout: 8,
            crowdAppeal: 5,
            personalFit: 4,
          },
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
    throw new Error(
      `Expected 2x markup, got ${recommendation.estimatedMarkup}`,
    );
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
          scores: {
            markupFairness: 6,
            producerPedigree: 5,
            menuStandout: 8,
            crowdAppeal: 5,
            personalFit: 4,
          },
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

Deno.test("normalizeScanResult defaults missing weak spots", () => {
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
          menuPriceUnit: "bottle",
          estimatedRetail: 36,
          scores: {
            markupFairness: 6,
            producerPedigree: 5,
            menuStandout: 8,
            crowdAppeal: 5,
            personalFit: 4,
          },
          why: "Balanced markup and strong food versatility.",
        },
      ],
    },
    "bottle",
  );

  if (result.weakSpots.length !== 0) {
    throw new Error(`Expected no weak spots, got ${result.weakSpots.length}`);
  }
});

Deno.test("normalizeScanResult normalizes weak spots", () => {
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
          menuPriceUnit: "bottle",
          estimatedRetail: 36,
          scores: {
            markupFairness: 6,
            producerPedigree: 5,
            menuStandout: 8,
            crowdAppeal: 5,
            personalFit: 4,
          },
          why: "Balanced markup and strong food versatility.",
        },
      ],
      weakSpots: [
        {
          categoryHeader: " Familiar labels ",
          explanation:
            " These bottles lean on recognition more than list context. ",
          reasons: [
            " Recognition-driven ",
            "Less distinctive",
            "Stronger picks nearby",
            "Fame tax",
            "Too safe",
          ],
          examples: [
            "Producer Famous Red 2021 120",
            "Producer Famous White 2022 95",
            "Producer Famous Rose 2023 88",
            "Producer Famous Sparkling NV 140",
            "Producer Famous Reserve 2020 180",
          ],
        },
      ],
    },
    "bottle",
  );

  const [weakSpot] = result.weakSpots;
  if (weakSpot.categoryHeader !== "Familiar labels") {
    throw new Error(`Unexpected weak spot header: ${weakSpot.categoryHeader}`);
  }

  if (
    weakSpot.explanation !==
      "These bottles lean on recognition more than list context."
  ) {
    throw new Error(
      `Unexpected weak spot explanation: ${weakSpot.explanation}`,
    );
  }

  if (weakSpot.reasons.length !== 4) {
    throw new Error(`Expected 4 reasons, got ${weakSpot.reasons.length}`);
  }

  if (weakSpot.reasons[0] !== "Recognition-driven") {
    throw new Error(`Unexpected weak spot reason: ${weakSpot.reasons[0]}`);
  }

  if (weakSpot.examples.length !== 4) {
    throw new Error(`Expected 4 examples, got ${weakSpot.examples.length}`);
  }
});

Deno.test("normalizeScanResult drops overpriced category recommendations", () => {
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
          menuPriceUnit: "bottle",
          estimatedRetail: 36,
          scores: {
            markupFairness: 6,
            producerPedigree: 5,
            menuStandout: 8,
            crowdAppeal: 5,
            personalFit: 4,
          },
          why: "Balanced markup and strong food versatility.",
        },
      ],
      categoryRecommendations: [
        {
          key: "overpriced_here",
          title: "Overpriced Here",
          recommendations: [
            {
              rank: 1,
              wineName: "Famous Red",
              extractedText: "Producer Famous Red bottle 120",
              producer: "Producer",
              region: "California",
              vintage: 2021,
              varietal: "Red Blend",
              menuPrice: 120,
              menuPriceUnit: "bottle",
              estimatedRetail: 40,
              scores: {
                markupFairness: 2,
                producerPedigree: 5,
                menuStandout: 2,
                crowdAppeal: 8,
                personalFit: 4,
              },
              why: "A familiar label has better alternatives nearby.",
            },
          ],
        },
      ],
    },
    "bottle",
  );

  if (result.categoryRecommendations.length !== 0) {
    throw new Error(
      `Expected overpriced category to be dropped, got ${result.categoryRecommendations.length}`,
    );
  }
});

Deno.test(
  "normalizeScanResult filters bottle recommendations when user selected glass",
  () => {
    const result = normalizeScanResult(
      {
        summary: {
          headline: "Best values on the list",
        },
        recommendations: [
          {
            rank: 1,
            wineName: "Estate Chardonnay",
            extractedText: "Producer Estate Chardonnay glass 18",
            producer: "Producer",
            region: "Willamette Valley",
            vintage: 2021,
            varietal: "Chardonnay",
            menuPrice: 18,
            menuPriceUnit: "glass",
            estimatedRetail: 45,
            scores: {
              markupFairness: 6,
              producerPedigree: 5,
              menuStandout: 8,
              crowdAppeal: 5,
              personalFit: 4,
            },
            why: "A glass value surfaced from the by-the-glass section.",
          },
          {
            rank: 2,
            wineName: "Estate Pinot Noir",
            extractedText: "Producer Estate Pinot Noir bottle 72",
            producer: "Producer",
            region: "Willamette Valley",
            vintage: 2021,
            varietal: "Pinot Noir",
            menuPrice: 72,
            menuPriceUnit: "bottle",
            estimatedRetail: 36,
            scores: {
              markupFairness: 6,
              producerPedigree: 5,
              menuStandout: 8,
              crowdAppeal: 5,
              personalFit: 4,
            },
            why:
              "A bottle value surfaced even though the user asked for glass.",
          },
        ],
        categoryRecommendations: [
          {
            key: "best_value",
            title: "Best Value",
            recommendations: [
              {
                rank: 1,
                wineName: "Estate Chardonnay",
                extractedText: "Producer Estate Chardonnay glass 18",
                producer: "Producer",
                region: "Willamette Valley",
                vintage: 2021,
                varietal: "Chardonnay",
                menuPrice: 18,
                menuPriceUnit: "glass",
                estimatedRetail: 45,
                scores: {
                  markupFairness: 6,
                  producerPedigree: 5,
                  menuStandout: 8,
                  crowdAppeal: 5,
                  personalFit: 4,
                },
                why: "A glass value surfaced from the by-the-glass section.",
              },
              {
                rank: 2,
                wineName: "Estate Pinot Noir",
                extractedText: "Producer Estate Pinot Noir bottle 72",
                producer: "Producer",
                region: "Willamette Valley",
                vintage: 2021,
                varietal: "Pinot Noir",
                menuPrice: 72,
                menuPriceUnit: "bottle",
                estimatedRetail: 36,
                scores: {
                  markupFairness: 6,
                  producerPedigree: 5,
                  menuStandout: 8,
                  crowdAppeal: 5,
                  personalFit: 4,
                },
                why:
                  "A bottle value surfaced even though the user asked for glass.",
              },
            ],
          },
          {
            key: "worth_the_splurge",
            title: "Worth the Splurge",
            recommendations: [
              {
                rank: 1,
                wineName: "Reserve Pinot Noir",
                extractedText: "Producer Reserve Pinot Noir bottle 120",
                producer: "Producer",
                region: "Willamette Valley",
                vintage: 2018,
                varietal: "Pinot Noir",
                menuPrice: 120,
                menuPriceUnit: "bottle",
                estimatedRetail: 60,
                scores: {
                  markupFairness: 6,
                  producerPedigree: 5,
                  menuStandout: 8,
                  crowdAppeal: 5,
                  personalFit: 4,
                },
                why:
                  "A bottle-only section should be removed for glass orders.",
              },
            ],
          },
        ],
      },
      "glass",
    );

    if (result.recommendations.length !== 1) {
      throw new Error(
        `Expected 1 glass recommendation, got ${result.recommendations.length}`,
      );
    }

    const [recommendation] = result.recommendations;
    if (recommendation.menuPriceUnit !== "glass") {
      throw new Error(
        `Expected glass price unit, got ${recommendation.menuPriceUnit}`,
      );
    }

    if (result.categoryRecommendations.length !== 1) {
      throw new Error(
        `Expected 1 category section, got ${result.categoryRecommendations.length}`,
      );
    }

    const [categoryRecommendation] =
      result.categoryRecommendations[0].recommendations;
    if (categoryRecommendation.menuPriceUnit !== "glass") {
      throw new Error(
        `Expected category glass price unit, got ${categoryRecommendation.menuPriceUnit}`,
      );
    }
  },
);

Deno.test(
  "normalizeScanResult rejects bottle-only recommendations when user selected glass",
  () => {
    let error: unknown;

    try {
      normalizeScanResult(
        {
          summary: {
            headline: "Best values on the list",
          },
          recommendations: [
            {
              rank: 1,
              wineName: "Estate Pinot Noir",
              extractedText: "Producer Estate Pinot Noir bottle 72",
              producer: "Producer",
              region: "Willamette Valley",
              vintage: 2021,
              varietal: "Pinot Noir",
              menuPrice: 72,
              menuPriceUnit: "bottle",
              estimatedRetail: 36,
              scores: {
                markupFairness: 6,
                producerPedigree: 5,
                menuStandout: 8,
                crowdAppeal: 5,
                personalFit: 4,
              },
              why:
                "A bottle value surfaced even though the user asked for glass.",
            },
          ],
        },
        "glass",
      );
    } catch (caughtError) {
      error = caughtError;
    }

    if (!(error instanceof Error) || error.message.length === 0) {
      throw new Error("Expected bottle-only glass result to be rejected.");
    }
  },
);

Deno.test(
  "normalizeScanResult derives list median markup from visible pricing sample",
  () => {
    const result = normalizeScanResult(
      {
        summary: {
          headline: "Best values on the list",
        },
        visiblePricingSample: [
          { menuPrice: 60, menuPriceUnit: "bottle", estimatedRetail: 30 },
          { menuPrice: 90, menuPriceUnit: "bottle", estimatedRetail: 30 },
          { menuPrice: 120, menuPriceUnit: "bottle", estimatedRetail: 30 },
        ],
        recommendations: [
          {
            rank: 1,
            wineName: "Estate Pinot Noir",
            extractedText: "Producer Estate Pinot Noir bottle 72",
            producer: "Producer",
            region: "Willamette Valley",
            vintage: 2021,
            varietal: "Pinot Noir",
            menuPrice: 72,
            menuPriceUnit: "bottle",
            estimatedRetail: 36,
            scores: {
              markupFairness: 6,
              producerPedigree: 5,
              menuStandout: 8,
              crowdAppeal: 5,
              personalFit: 4,
            },
            why:
              "A bottle value surfaced even though the user asked for glass.",
          },
        ],
      },
      "bottle",
    );

    if (result.pricingContextSummary.markupSampleSize !== 3) {
      throw new Error(
        `Expected 3 usable markup samples, got ${result.pricingContextSummary.markupSampleSize}`,
      );
    }

    if (result.pricingContextSummary.medianEstimatedMarkup !== 3) {
      throw new Error(
        `Expected 3x median markup, got ${result.pricingContextSummary.medianEstimatedMarkup}`,
      );
    }
  },
);

Deno.test("normalizeScanResult derives even list median markup", () => {
  const result = normalizeScanResult(
    {
      summary: {
        headline: "Best values on the list",
      },
      visiblePricingSample: [
        { menuPrice: 60, menuPriceUnit: "bottle", estimatedRetail: 30 },
        { menuPrice: 90, menuPriceUnit: "bottle", estimatedRetail: 30 },
        { menuPrice: 120, menuPriceUnit: "bottle", estimatedRetail: 30 },
        { menuPrice: 150, menuPriceUnit: "bottle", estimatedRetail: 30 },
      ],
      recommendations: [
        {
          rank: 1,
          wineName: "Estate Pinot Noir",
          extractedText: "Producer Estate Pinot Noir bottle 72",
          producer: "Producer",
          region: "Willamette Valley",
          vintage: 2021,
          varietal: "Pinot Noir",
          menuPrice: 72,
          menuPriceUnit: "bottle",
          estimatedRetail: 36,
          scores: {
            markupFairness: 6,
            producerPedigree: 5,
            menuStandout: 8,
            crowdAppeal: 5,
            personalFit: 4,
          },
          why: "A bottle value surfaced even though the user asked for glass.",
        },
      ],
    },
    "bottle",
  );

  if (result.pricingContextSummary.medianEstimatedMarkup !== 3.5) {
    throw new Error(
      `Expected 3.5x median markup, got ${result.pricingContextSummary.medianEstimatedMarkup}`,
    );
  }
});

Deno.test(
  "normalizeScanResult handles glass and invalid pricing sample entries",
  () => {
    const result = normalizeScanResult(
      {
        summary: {
          headline: "Best values on the list",
        },
        visiblePricingSample: [
          { menuPrice: 18, menuPriceUnit: "glass", estimatedRetail: 45 },
          { menuPrice: 27, menuPriceUnit: "glass", estimatedRetail: 45 },
          { menuPrice: 36, menuPriceUnit: "glass", estimatedRetail: 45 },
          { menuPrice: null, menuPriceUnit: "bottle", estimatedRetail: 30 },
          { menuPrice: 60, menuPriceUnit: "bottle", estimatedRetail: 0 },
        ],
        recommendations: [
          {
            rank: 1,
            wineName: "Estate Pinot Noir",
            extractedText: "Producer Estate Pinot Noir glass 18",
            producer: "Producer",
            region: "Willamette Valley",
            vintage: 2021,
            varietal: "Pinot Noir",
            menuPrice: 18,
            menuPriceUnit: "glass",
            estimatedRetail: 45,
            scores: {
              markupFairness: 6,
              producerPedigree: 5,
              menuStandout: 8,
              crowdAppeal: 5,
              personalFit: 4,
            },
            why: "A glass value surfaced from the by-the-glass section.",
          },
        ],
      },
      "glass",
    );

    if (result.pricingContextSummary.markupSampleSize !== 3) {
      throw new Error(
        `Expected 3 usable markup samples, got ${result.pricingContextSummary.markupSampleSize}`,
      );
    }

    if (result.pricingContextSummary.medianEstimatedMarkup !== 3) {
      throw new Error(
        `Expected 3x glass median markup, got ${result.pricingContextSummary.medianEstimatedMarkup}`,
      );
    }
  },
);

Deno.test(
  "normalizeScanResult returns null median when pricing sample is too small",
  () => {
    const result = normalizeScanResult(
      {
        summary: {
          headline: "Best values on the list",
        },
        visiblePricingSample: [
          { menuPrice: 60, menuPriceUnit: "bottle", estimatedRetail: 30 },
          { menuPrice: 90, menuPriceUnit: "bottle", estimatedRetail: 30 },
        ],
        recommendations: [
          {
            rank: 1,
            wineName: "Estate Pinot Noir",
            extractedText: "Producer Estate Pinot Noir bottle 72",
            producer: "Producer",
            region: "Willamette Valley",
            vintage: 2021,
            varietal: "Pinot Noir",
            menuPrice: 72,
            menuPriceUnit: "bottle",
            estimatedRetail: 36,
            scores: {
              markupFairness: 6,
              producerPedigree: 5,
              menuStandout: 8,
              crowdAppeal: 5,
              personalFit: 4,
            },
            why:
              "A bottle value surfaced even though the user asked for glass.",
          },
        ],
      },
      "bottle",
    );

    if (result.pricingContextSummary.markupSampleSize !== 2) {
      throw new Error(
        `Expected 2 usable markup samples, got ${result.pricingContextSummary.markupSampleSize}`,
      );
    }

    if (result.pricingContextSummary.medianEstimatedMarkup !== null) {
      throw new Error(
        `Expected null median markup, got ${result.pricingContextSummary.medianEstimatedMarkup}`,
      );
    }
  },
);
