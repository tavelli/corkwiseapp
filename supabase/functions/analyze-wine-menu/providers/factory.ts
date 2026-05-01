import {RequestError, type WineModelProvider} from "../domain/types.ts";
import {GeminiProvider} from "./gemini.ts";
import {OpenAIProvider} from "./openai.ts";

const DEFAULT_PROVIDER = "openai";

export function makeProvider(): WineModelProvider {
  const providerName = Deno.env.get("MODEL_PROVIDER")?.trim().toLowerCase() ??
    DEFAULT_PROVIDER;

  switch (providerName) {
    case "openai":
      return new OpenAIProvider();
    case "gemini":
      return new GeminiProvider();
    default:
      throw new RequestError(
        500,
        "analysis_failed",
        `Unsupported MODEL_PROVIDER '${providerName}'.`,
        false,
      );
  }
}
