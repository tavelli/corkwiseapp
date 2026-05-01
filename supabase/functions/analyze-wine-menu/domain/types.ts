export type PurchaseMode = "glass" | "bottle";

export type AnalyzeWineMenuRequest = {
  imageBase64: string;
  purchaseMode: PurchaseMode;
  userPreferences: {
    experienceLevel: string;
    preferredStyles: string[];
    choiceStyle: string;
  };
};

export type WineAnalysisErrorResponse = {
  error: string;
  message: string;
  retrySuggested: boolean;
};

export type WineScanResult = {
  restaurantName: string | null;
  summary: {
    headline: string;
    bestPickName: string;
    bestPickScore: number;
    bestPickWhy: string;
  };
  recommendations: Array<{
    rank: number;
    wineName: string;
    menuPrice: number | null;
    estimatedRetailLow: number | null;
    estimatedRetailHigh: number | null;
    estimatedMarkupLow: number | null;
    estimatedMarkupHigh: number | null;
    estimatedMarkupDisplay: string | null;
    valueScore: number;
    why: string;
  }>;
  categoryRecommendations: Array<{
    key: string;
    title: string;
    recommendations: Array<{
      rank: number;
      wineName: string;
      menuPrice: number | null;
      estimatedRetailLow: number | null;
      estimatedRetailHigh: number | null;
      estimatedMarkupLow: number | null;
      estimatedMarkupHigh: number | null;
      estimatedMarkupDisplay: string | null;
      valueScore: number;
      why: string;
    }>;
  }>;
  notes: string[];
  debugInfo?: {
    model: string;
    apiDurationMilliseconds: number;
  };
};

export type AnalysisProviderName = "openai" | "gemini";

export type ProviderAnalysisResult = {
  payload: unknown;
  provider: AnalysisProviderName;
  model: string;
  apiDurationMilliseconds: number;
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
