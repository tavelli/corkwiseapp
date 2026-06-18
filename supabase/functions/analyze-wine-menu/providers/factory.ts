import { RequestError, type WineModelProvider } from "../domain/types.ts";
import { ModelFallbackProvider, modelSequence } from "./fallback.ts";
import { GeminiProvider } from "./gemini.ts";
import { OpenAIProvider } from "./openai.ts";

const DEFAULT_PROVIDER = "openai";
const DEFAULT_OPENAI_MODEL = "gpt-4o";
const DEFAULT_GEMINI_MODEL = "gemini-3-flash-preview";

export function makeProvider(): WineModelProvider {
  const providerName = Deno.env.get("MODEL_PROVIDER")?.trim().toLowerCase() ??
    DEFAULT_PROVIDER;

  switch (providerName) {
    case "openai": {
      const models = modelSequence(
        Deno.env.get("OPENAI_MODEL") ?? DEFAULT_OPENAI_MODEL,
        Deno.env.get("OPENAI_FALLBACK_MODELS"),
      );
      return new ModelFallbackProvider(
        "openai",
        models,
        (model) => new OpenAIProvider({ model }),
      );
    }
    case "gemini": {
      const models = modelSequence(
        Deno.env.get("GEMINI_MODEL") ?? DEFAULT_GEMINI_MODEL,
        Deno.env.get("GEMINI_FALLBACK_MODELS"),
      );
      return new ModelFallbackProvider(
        "gemini",
        models,
        (model) => new GeminiProvider({ model }),
      );
    }
    default:
      throw new RequestError(
        500,
        "analysis_failed",
        `Unsupported MODEL_PROVIDER '${providerName}'.`,
        false,
      );
  }
}
