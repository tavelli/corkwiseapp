import {RequestError} from "./types.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

export type FreeScanAllowance = {
  allowed: boolean;
  freeScansUsed: number;
};

export async function upsertAppInstallation(
  appUserId: string,
  supabaseUserId: string,
  appleOriginalTransactionId: string | null,
  buildConfiguration: string | undefined,
): Promise<void> {
  const body: {
    keychain_app_user_id: string;
    supabase_user_id: string;
    updated_at: string;
    apple_original_transaction_id?: string;
    build_configuration?: string;
  } = {
    keychain_app_user_id: appUserId,
    supabase_user_id: supabaseUserId,
    updated_at: new Date().toISOString(),
  };

  if (appleOriginalTransactionId != null) {
    body.apple_original_transaction_id = appleOriginalTransactionId;
  }

  if (buildConfiguration != null) {
    body.build_configuration = buildConfiguration;
  }

  const response = await fetch(
    `${restURL()}/app_installations?on_conflict=keychain_app_user_id`,
    {
      method: "POST",
      headers: restHeaders({
        Prefer: "resolution=merge-duplicates",
      }),
      body: JSON.stringify(body),
    },
  );

  if (response.ok === false) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while preparing the scan.",
      true,
    );
  }
}

export async function checkFreeScanAllowance(
  appUserId: string,
  freeScanLimit: number,
): Promise<FreeScanAllowance> {
  const response = await fetch(`${restURL()}/rpc/free_scan_allowance`, {
    method: "POST",
    headers: restHeaders(),
    body: JSON.stringify({
      p_keychain_app_user_id: appUserId,
      p_free_scan_limit: freeScanLimit,
    }),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while preparing the scan.",
      true,
    );
  }

  return freeScanAllowanceFromResponse(await response.json());
}

export async function consumeFreeScan(
  appUserId: string,
  freeScanLimit: number,
): Promise<FreeScanAllowance> {
  const response = await fetch(`${restURL()}/rpc/consume_free_scan`, {
    method: "POST",
    headers: restHeaders(),
    body: JSON.stringify({
      p_keychain_app_user_id: appUserId,
      p_free_scan_limit: freeScanLimit,
    }),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while preparing the scan.",
      true,
    );
  }

  return freeScanAllowanceFromResponse(await response.json());
}

function freeScanAllowanceFromResponse(responseBody: unknown): FreeScanAllowance {
  const [result] = responseBody as Array<{
    allowed: boolean;
    free_scans_used: number;
  }>;

  return {
    allowed: result?.allowed === true,
    freeScansUsed: result?.free_scans_used ?? 0,
  };
}

function restURL(): string {
  if (SUPABASE_URL == null || SUPABASE_SERVICE_ROLE_KEY == null) {
    throw new RequestError(
      500,
      "analysis_failed",
      "The backend is missing required Supabase configuration.",
      false,
    );
  }

  return `${SUPABASE_URL}/rest/v1`;
}

function restHeaders(extraHeaders: HeadersInit = {}): HeadersInit {
  return {
    apikey: SUPABASE_SERVICE_ROLE_KEY!,
    Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    "Content-Type": "application/json",
    ...extraHeaders,
  };
}
