import {
  scanAccessForRequest,
  validateScanAccessRequest,
} from "./scan-access.ts";
import { RequestError } from "./types.ts";

const appUserId = "7e95be64-3a08-4b6f-9943-61b9c1d15525";
const supabaseUserId = "a91d43df-4bdb-48d4-9cb7-e9d59f1460b2";

Deno.test("scanAccessForRequest allows paid users", async () => {
  const access = await scanAccessForRequest(
    { action: "scan_access", appUserId, buildConfiguration: "testflight" },
    supabaseUserId,
    1,
    {
      checkEntitlement: () =>
        Promise.resolve({
          isPaid: true,
          appleOriginalTransactionId: "apple-transaction-id",
        }),
      upsertAppInstallation: () => Promise.resolve(),
      checkFreeScanAllowance: () => {
        throw new Error(
          "Free scan allowance should not be checked for paid users.",
        );
      },
    },
  );

  if (access.hasActiveEntitlement !== true) {
    throw new Error("Expected paid access.");
  }
});

Deno.test("scanAccessForRequest allows unpaid users with free allowance", async () => {
  const access = await scanAccessForRequest(
    { action: "scan_access", appUserId },
    supabaseUserId,
    1,
    {
      checkEntitlement: () =>
        Promise.resolve({ isPaid: false, appleOriginalTransactionId: null }),
      upsertAppInstallation: () => Promise.resolve(),
      checkFreeScanAllowance: () =>
        Promise.resolve({ allowed: true, freeScansUsed: 0 }),
    },
  );

  if (access.hasFreeScanAllowance !== true || access.freeScansUsed !== 0) {
    throw new Error("Expected free scan allowance.");
  }
});

Deno.test("scanAccessForRequest requires purchase when allowance is exhausted", async () => {
  const access = await scanAccessForRequest(
    { action: "scan_access", appUserId },
    supabaseUserId,
    1,
    {
      checkEntitlement: () =>
        Promise.resolve({ isPaid: false, appleOriginalTransactionId: null }),
      upsertAppInstallation: () => Promise.resolve(),
      checkFreeScanAllowance: () =>
        Promise.resolve({ allowed: false, freeScansUsed: 1 }),
      availableRetryCredit: () => Promise.resolve(null),
    },
  );

  if (
    access.hasFreeScanAllowance !== false || access.hasRetryCredit !== false ||
    access.freeScansUsed !== 1
  ) {
    throw new Error("Expected exhausted free scan allowance.");
  }
});

Deno.test("scanAccessForRequest requires purchase when free scans are disabled", async () => {
  const access = await scanAccessForRequest(
    { action: "scan_access", appUserId },
    supabaseUserId,
    0,
    {
      checkEntitlement: () =>
        Promise.resolve({ isPaid: false, appleOriginalTransactionId: null }),
      upsertAppInstallation: () => Promise.resolve(),
      checkFreeScanAllowance: () => {
        throw new Error(
          "Free scan allowance should not be checked when disabled.",
        );
      },
      availableRetryCredit: () => Promise.resolve(null),
    },
  );

  if (
    access.hasFreeScanAllowance !== false || access.hasRetryCredit !== false ||
    access.freeScanLimit !== 0
  ) {
    throw new Error("Expected free scans to be disabled.");
  }
});

Deno.test("scanAccessForRequest allows unpaid users with retry credit", async () => {
  const access = await scanAccessForRequest(
    { action: "scan_access", appUserId },
    supabaseUserId,
    1,
    {
      checkEntitlement: () =>
        Promise.resolve({ isPaid: false, appleOriginalTransactionId: null }),
      upsertAppInstallation: () => Promise.resolve(),
      checkFreeScanAllowance: () =>
        Promise.resolve({ allowed: false, freeScansUsed: 1 }),
      availableRetryCredit: () => Promise.resolve({ id: crypto.randomUUID() }),
    },
  );

  if (access.hasRetryCredit !== true || access.hasFreeScanAllowance !== false) {
    throw new Error("Expected retry credit access.");
  }
});

Deno.test("validateScanAccessRequest rejects invalid app user IDs", () => {
  try {
    validateScanAccessRequest({
      action: "scan_access",
      appUserId: "not-a-uuid",
    });
  } catch (error) {
    if (error instanceof RequestError && error.status === 400) {
      return;
    }

    throw error;
  }

  throw new Error("Expected invalid app user ID to throw.");
});

Deno.test("validateScanAccessRequest normalizes app user IDs", () => {
  const request = validateScanAccessRequest({
    action: "scan_access",
    appUserId: appUserId.toUpperCase(),
  });

  if (request.appUserId !== appUserId) {
    throw new Error("Expected lowercase app user ID.");
  }
});
