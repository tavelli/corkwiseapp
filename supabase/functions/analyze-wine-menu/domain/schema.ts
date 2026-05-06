export const modelResponseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    restaurantName: {type: ["string", "null"]},
    summary: {
      type: "object",
      additionalProperties: false,
      properties: {
        headline: {type: "string"},
        bestPickName: {type: "string"},
        bestPickScore: {type: "number"},
        bestPickWhy: {type: "string"},
      },
      required: ["headline", "bestPickName", "bestPickScore", "bestPickWhy"],
    },
    recommendations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          rank: {type: "integer"},
          wineName: {type: "string"},
          menuPrice: {type: ["number", "null"]},
          estimatedRetail: {type: ["number", "null"]},
          valueScore: {type: "number"},
          why: {type: "string"},
        },
        required: [
          "rank",
          "wineName",
          "menuPrice",
          "estimatedRetail",
          "valueScore",
          "why",
        ],
      },
    },
    categoryRecommendations: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          key: {type: "string"},
          title: {type: "string"},
          recommendations: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                rank: {type: "integer"},
                wineName: {type: "string"},
                menuPrice: {type: ["number", "null"]},
                estimatedRetail: {type: ["number", "null"]},
                valueScore: {type: "number"},
                why: {type: "string"},
              },
              required: [
                "rank",
                "wineName",
                "menuPrice",
                "estimatedRetail",
                "valueScore",
                "why",
              ],
            },
          },
        },
        required: ["key", "title", "recommendations"],
      },
    },
    notes: {
      type: "array",
      items: {type: "string"},
    },
  },
  required: [
    "restaurantName",
    "summary",
    "recommendations",
    "categoryRecommendations",
    "notes",
  ],
} as const;
