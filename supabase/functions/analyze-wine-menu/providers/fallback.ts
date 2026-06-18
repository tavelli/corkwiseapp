import {
  type AnalysisProviderName,
  type AnalyzeWineMenuRequest,
  type ProviderAnalysisResult,
  ProviderRateLimitError,
  RequestError,
  type WineModelProvider,
} from "../domain/types.ts";

type ProviderFactory = (model: string) => WineModelProvider;

export class ModelFallbackProvider implements WineModelProvider {
  private readonly provider: AnalysisProviderName;
  private readonly models: string[];
  private readonly makeProvider: ProviderFactory;

  constructor(
    provider: AnalysisProviderName,
    models: string[],
    makeProvider: ProviderFactory,
  ) {
    this.provider = provider;
    this.models = models;
    this.makeProvider = makeProvider;
  }

  async analyzeMenu(
    requestBody: AnalyzeWineMenuRequest,
  ): Promise<ProviderAnalysisResult> {
    for (const [index, model] of this.models.entries()) {
      try {
        return await this.makeProvider(model).analyzeMenu(requestBody);
      } catch (error) {
        if (error instanceof ProviderRateLimitError === false) {
          throw error;
        }

        const hasFallback = index < this.models.length - 1;
        console.warn(`${this.provider} model rate limited`, {
          model: error.model,
          fallbackModel: hasFallback ? this.models[index + 1] : null,
        });

        if (hasFallback === false) {
          throw new RequestError(
            502,
            "analysis_failed",
            "Something went wrong while analyzing the wine list.",
            true,
          );
        }
      }
    }

    throw new RequestError(
      502,
      "analysis_failed",
      "Something went wrong while analyzing the wine list.",
      true,
    );
  }
}

export function modelSequence(
  primaryModel: string,
  fallbackModelsValue: string | undefined,
): string[] {
  const models = [primaryModel, ...parseModelList(fallbackModelsValue)];
  const seen = new Set<string>();

  return models.filter((model) => {
    const normalized = model.trim();
    if (normalized.length === 0 || seen.has(normalized)) {
      return false;
    }

    seen.add(normalized);
    return true;
  });
}

function parseModelList(value: string | undefined): string[] {
  if (value == null) {
    return [];
  }

  return value
    .split(",")
    .map((model) => model.trim())
    .filter((model) => model.length > 0);
}
