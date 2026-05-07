export type PurchaseMode = "glass" | "bottle";

export type WineCategoryPreference =
  | "anything"
  | "reds"
  | "whites"
  | "sparkling";

export type AnalyzeWineMenuAttachment = {
  base64Data: string;
  mimeType: "image/jpeg" | "application/pdf";
  filename?: string | null;
};

export type AnalyzeWineMenuSource =
  | {
      kind: "attachment";
      attachment: AnalyzeWineMenuAttachment;
    }
  | {
      kind: "url";
      menuUrl: string;
    };

export type AnalyzeWineMenuRequest = {
  source: AnalyzeWineMenuSource;
  purchaseMode: PurchaseMode;
  categoryPreference: WineCategoryPreference;
  userPreferences: {
    preferredStyles: string[];
    favoriteVarietals: string[];
    choiceStyle: string;
    tone: string;
  };
};

export type WineAnalysisErrorResponse = {
  error: string;
  message: string;
  retrySuggested: boolean;
};

export type TokenUsage = {
  promptTokenCount: number;
  candidatesTokenCount: number;
  totalTokenCount: number;
};

export type WineScanResult = {
  restaurantName: string | null;
  summary: {
    headline: string;
  };
  recommendations: Array<{
    rank: number;
    wineName: string;
    displayName: string;
    extractedText: string;
    producer: string | null;
    region: string | null;
    vintage: number | null;
    varietal: string | null;
    menuPrice: number | null;
    estimatedRetail: number | null;
    estimatedMarkup: number | null;
    valueScore: number;
    why: string;
  }>;
  categoryRecommendations: Array<{
    key: string;
    title: string;
    recommendations: Array<{
      rank: number;
      wineName: string;
      displayName: string;
      extractedText: string;
      producer: string | null;
      region: string | null;
      vintage: number | null;
      varietal: string | null;
      menuPrice: number | null;
      estimatedRetail: number | null;
      estimatedMarkup: number | null;
      valueScore: number;
      why: string;
    }>;
  }>;
  notes: string[];
  debugInfo?: {
    model: string;
    apiDurationMilliseconds: number;
    usage?: TokenUsage;
    totalCostUsd?: number;
  };
};

export type AnalysisProviderName = "openai" | "gemini";

export type ProviderAnalysisResult = {
  payload: unknown;
  provider: AnalysisProviderName;
  model: string;
  apiDurationMilliseconds: number;
  usage?: TokenUsage;
  totalCostUsd?: number;
};

export interface WineModelProvider {
  analyzeMenu(
    requestBody: AnalyzeWineMenuRequest,
  ): Promise<ProviderAnalysisResult>;
}

export class RequestError extends Error {
  status: number;
  responseBody: WineAnalysisErrorResponse;

  constructor(
    status: number,
    error: string,
    message: string,
    retrySuggested: boolean,
  ) {
    super(message);
    this.status = status;
    this.responseBody = {error, message, retrySuggested};
  }
}
