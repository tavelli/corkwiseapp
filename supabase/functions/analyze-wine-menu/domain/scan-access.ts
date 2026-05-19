import {
  checkFreeScanAllowance,
  type FreeScanAllowance,
  upsertAppInstallation,
} from "./app-installations.ts";
import { availableRetryCredit, type RetryCredit } from "./retry-credits.ts";
import { checkEntitlement, type EntitlementState } from "./adapty.ts";
import { RequestError } from "./types.ts";

export type ScanAccessRequest = {
  action: "scan_access";
  appUserId: string;
  buildConfiguration?: "debug" | "testflight" | "appstore" | "release_unknown";
};

export type ScanAccessResponse = {
  hasActiveEntitlement: boolean;
  hasFreeScanAllowance: boolean;
  hasRetryCredit: boolean;
  freeScansUsed: number;
  freeScanLimit: number;
};

type ScanAccessDependencies = {
  checkEntitlement?: (appUserId: string) => Promise<EntitlementState>;
  upsertAppInstallation?: (
    appUserId: string,
    supabaseUserId: string,
    appleOriginalTransactionId: string | null,
    buildConfiguration: string | undefined,
  ) => Promise<void>;
  checkFreeScanAllowance?: (
    appUserId: string,
    freeScanLimit: number,
  ) => Promise<FreeScanAllowance>;
  availableRetryCredit?: (appUserId: string) => Promise<RetryCredit | null>;
};

export function validateScanAccessRequest(input: unknown): ScanAccessRequest {
  if (input == null || typeof input !== "object") {
    throw new RequestError(
      400,
      "invalid_request",
      "Request body must be a JSON object.",
      false,
    );
  }

  const candidate = input as Record<string, unknown>;
  const action = stringOrNull(candidate.action);
  const appUserId = stringOrNull(candidate.appUserId);
  const buildConfiguration = buildConfigurationOrNull(
    candidate.buildConfiguration,
  );

  if (action !== "scan_access") {
    throw new RequestError(
      400,
      "invalid_request",
      "Unsupported action.",
      false,
    );
  }

  if (appUserId == null || isUUID(appUserId) === false) {
    throw new RequestError(
      400,
      "invalid_request",
      "appUserId must be a valid UUID.",
      false,
    );
  }

  return {
    action,
    appUserId,
    ...(buildConfiguration == null ? {} : { buildConfiguration }),
  };
}

export async function scanAccessForRequest(
  request: ScanAccessRequest,
  supabaseUserId: string,
  freeScanLimit: number,
  dependencies: ScanAccessDependencies = {},
): Promise<ScanAccessResponse> {
  const entitlement = await (dependencies.checkEntitlement ?? checkEntitlement)(
    request.appUserId,
  );

  await (dependencies.upsertAppInstallation ?? upsertAppInstallation)(
    request.appUserId,
    supabaseUserId,
    entitlement.appleOriginalTransactionId,
    request.buildConfiguration,
  );

  if (entitlement.isPaid) {
    return {
      hasActiveEntitlement: true,
      hasFreeScanAllowance: false,
      hasRetryCredit: false,
      freeScansUsed: 0,
      freeScanLimit,
    };
  }

  if (freeScanLimit <= 0) {
    const retryCredit = await (
      dependencies.availableRetryCredit ?? availableRetryCredit
    )(request.appUserId);

    return {
      hasActiveEntitlement: false,
      hasFreeScanAllowance: false,
      hasRetryCredit: retryCredit != null,
      freeScansUsed: 0,
      freeScanLimit,
    };
  }

  const allowance = await (
    dependencies.checkFreeScanAllowance ?? checkFreeScanAllowance
  )(request.appUserId, freeScanLimit);
  const retryCredit = allowance.allowed
    ? null
    : await (dependencies.availableRetryCredit ?? availableRetryCredit)(
      request.appUserId,
    );

  return {
    hasActiveEntitlement: false,
    hasFreeScanAllowance: allowance.allowed,
    hasRetryCredit: retryCredit != null,
    freeScansUsed: allowance.freeScansUsed,
    freeScanLimit,
  };
}

function stringOrNull(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }

  const trimmedValue = value.trim();
  return trimmedValue.length === 0 ? null : trimmedValue;
}

function buildConfigurationOrNull(
  value: unknown,
): ScanAccessRequest["buildConfiguration"] | null {
  const buildConfiguration = stringOrNull(value);
  switch (buildConfiguration) {
    case "debug":
    case "testflight":
    case "appstore":
    case "release_unknown":
      return buildConfiguration;
    case null:
      return null;
    default:
      throw new RequestError(
        400,
        "invalid_request",
        "buildConfiguration is invalid.",
        false,
      );
  }
}

function isUUID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
