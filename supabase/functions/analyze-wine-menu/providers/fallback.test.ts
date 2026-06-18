import {
  type AnalyzeWineMenuRequest,
  type ProviderAnalysisResult,
  ProviderRateLimitError,
  RequestError,
  type WineModelProvider,
} from "../domain/types.ts";
import { ModelFallbackProvider, modelSequence } from "./fallback.ts";
import { GeminiProvider } from "./gemini.ts";
import { OpenAIProvider } from "./openai.ts";

const requestBody: AnalyzeWineMenuRequest = {
  appUserId: "7e95be64-3a08-4b6f-9943-61b9c1d15525",
  source: {
    kind: "attachment",
    attachments: [{
      base64Data: "abc123",
      mimeType: "image/jpeg",
      filename: "menu.jpg",
    }],
  },
  purchaseMode: "bottle",
  categoryPreference: "anything",
  pricingContext: {
    localeIdentifier: "en_US",
    currencyCode: "USD",
  },
  userPreferences: {
    preferredStyles: [],
    favoriteVarietals: [],
    choiceStyle: "value",
    tone: "standard",
  },
};

Deno.test("modelSequence preserves primary model and opt-in fallback models", () => {
  const models = modelSequence("gpt-4o", "gpt-4o-mini, gpt-4.1-mini");

  assertEquals(models, ["gpt-4o", "gpt-4o-mini", "gpt-4.1-mini"]);
});

Deno.test("modelSequence keeps current single-model behavior without fallback env", () => {
  const models = modelSequence("gpt-4o", undefined);

  assertEquals(models, ["gpt-4o"]);
});

Deno.test("modelSequence removes blank and duplicate fallback models", () => {
  const models = modelSequence("gpt-4o", "gpt-4o-mini,,gpt-4o-mini, gpt-4.1");

  assertEquals(models, ["gpt-4o", "gpt-4o-mini", "gpt-4.1"]);
});

Deno.test("ModelFallbackProvider does not call fallback after primary success", async () => {
  const calls: string[] = [];
  const provider = new ModelFallbackProvider(
    "openai",
    ["primary", "fallback"],
    (
      model,
    ) => new FakeProvider(model, calls, "success"),
  );

  const result = await provider.analyzeMenu(requestBody);

  assertEquals(calls, ["primary"]);
  assertEquals(result.model, "primary");
});

Deno.test("ModelFallbackProvider tries next model after rate limit", async () => {
  const calls: string[] = [];
  const provider = new ModelFallbackProvider(
    "openai",
    ["primary", "fallback"],
    (
      model,
    ) =>
      new FakeProvider(
        model,
        calls,
        model === "primary" ? "rate_limit" : "success",
      ),
  );

  const result = await provider.analyzeMenu(requestBody);

  assertEquals(calls, ["primary", "fallback"]);
  assertEquals(result.model, "fallback");
});

Deno.test("ModelFallbackProvider does not retry non-rate-limit failures", async () => {
  const calls: string[] = [];
  const provider = new ModelFallbackProvider(
    "openai",
    ["primary", "fallback"],
    (
      model,
    ) => new FakeProvider(model, calls, "failure"),
  );

  await assertRejects(
    () => provider.analyzeMenu(requestBody),
    RequestError,
    "non-rate-limit",
  );
  assertEquals(calls, ["primary"]);
});

Deno.test("ModelFallbackProvider returns retryable failure after all models are rate limited", async () => {
  const provider = new ModelFallbackProvider(
    "openai",
    ["primary", "fallback"],
    (
      model,
    ) => new FakeProvider(model, [], "rate_limit"),
  );

  const error = await assertRejects(
    () => provider.analyzeMenu(requestBody),
    RequestError,
  );

  assertEquals(error.status, 502);
  assertEquals(error.responseBody.error, "analysis_failed");
  assertEquals(error.responseBody.retrySuggested, true);
});

Deno.test("OpenAIProvider maps upstream 429 to ProviderRateLimitError", async () => {
  const provider = new OpenAIProvider({
    model: "gpt-4o",
    apiKey: "test-key",
    fetch: rateLimitFetch,
  });

  const error = await assertRejects(
    () => provider.analyzeMenu(requestBody),
    ProviderRateLimitError,
  );

  assertEquals(error.provider, "openai");
  assertEquals(error.model, "gpt-4o");
});

Deno.test("GeminiProvider maps upstream 429 to ProviderRateLimitError", async () => {
  const provider = new GeminiProvider({
    model: "gemini-3-flash-preview",
    apiKey: "test-key",
    fetch: rateLimitFetch,
  });

  const error = await assertRejects(
    () => provider.analyzeMenu(requestBody),
    ProviderRateLimitError,
  );

  assertEquals(error.provider, "gemini");
  assertEquals(error.model, "gemini-3-flash-preview");
});

type FakeProviderBehavior = "success" | "rate_limit" | "failure";

class FakeProvider implements WineModelProvider {
  constructor(
    private readonly model: string,
    private readonly calls: string[],
    private readonly behavior: FakeProviderBehavior,
  ) {}

  analyzeMenu(): Promise<ProviderAnalysisResult> {
    this.calls.push(this.model);

    switch (this.behavior) {
      case "success":
        return Promise.resolve({
          payload: {},
          provider: "openai",
          model: this.model,
          apiDurationMilliseconds: 1,
        });
      case "rate_limit":
        throw new ProviderRateLimitError("openai", this.model);
      case "failure":
        throw new RequestError(
          502,
          "analysis_failed",
          "non-rate-limit",
          true,
        );
    }
  }
}

const rateLimitFetch: typeof fetch = () =>
  Promise.resolve(new Response("rate limit", { status: 429 }));

function assertEquals<T>(actual: T, expected: T) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }.`,
    );
  }
}

async function assertRejects<T extends Error>(
  action: () => Promise<unknown>,
  errorClass: new (...args: never[]) => T,
  messageIncludes?: string,
): Promise<T> {
  try {
    await action();
  } catch (error) {
    if (error instanceof errorClass) {
      if (
        messageIncludes != null &&
        error.message.includes(messageIncludes) === false
      ) {
        throw new Error(
          `Expected error message to include '${messageIncludes}', received '${error.message}'.`,
        );
      }

      return error;
    }

    throw error;
  }

  throw new Error(`Expected ${errorClass.name} to throw.`);
}
