import {RequestError} from "./types.ts";

const ADAPTY_PROFILE_URL = "https://api.adapty.io/api/v2/server-side-api/profile/";
const ADAPTY_SECRET_API_KEY = Deno.env.get("ADAPTY_SECRET_API_KEY");
const ADAPTY_ACCESS_LEVEL_ID = Deno.env.get("ADAPTY_ACCESS_LEVEL_ID") ?? "premium";

export type EntitlementState = {
  isPaid: boolean;
  appleOriginalTransactionId: string | null;
};

type AdaptyProfileResponse = {
  data?: {
    access_levels?: Array<{
      access_level_id?: string;
      is_active?: boolean;
      starts_at?: string | null;
      expires_at?: string | null;
      store?: string;
      store_original_transaction_id?: string | null;
    }>;
    paid_access_levels?: AccessLevelCollection;
    subscriptions?: Array<{
      store?: string;
      store_original_transaction_id?: string | null;
    }>;
  };
};

type AccessLevel = {
  access_level_id?: string;
  is_active?: boolean;
  starts_at?: string | null;
  expires_at?: string | null;
  store?: string;
  store_original_transaction_id?: string | null;
};

type AccessLevelCollection = Array<AccessLevel> | Record<string, AccessLevel>;

export async function checkEntitlement(appUserId: string): Promise<EntitlementState> {
  if (ADAPTY_SECRET_API_KEY == null || ADAPTY_SECRET_API_KEY.length === 0) {
    throw new RequestError(
      500,
      "analysis_failed",
      "The backend is missing required entitlement configuration.",
      false,
    );
  }

  const response = await fetch(ADAPTY_PROFILE_URL, {
    headers: {
      Accept: "application/json",
      Authorization: `Api-Key ${ADAPTY_SECRET_API_KEY}`,
      "adapty-customer-user-id": appUserId,
    },
  });

  if (response.status === 404) {
    return {
      isPaid: false,
      appleOriginalTransactionId: null,
    };
  }

  if (response.ok === false) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while checking subscription access.",
      true,
    );
  }

  const body = await response.json() as AdaptyProfileResponse;
  const accessLevels = normalizeAccessLevels(
    body.data?.access_levels ?? body.data?.paid_access_levels,
  );
  const activeAccessLevel = accessLevels?.find((accessLevel) =>
    accessLevel.access_level_id === ADAPTY_ACCESS_LEVEL_ID &&
    accessLevelIsActive(accessLevel)
  );

  console.log("adapty entitlement checked", {
    requestedAccessLevelID: ADAPTY_ACCESS_LEVEL_ID,
    returnedAccessLevelIDs:
      accessLevels?.map((accessLevel) => accessLevel.access_level_id) ?? [],
    isPaid: activeAccessLevel != null,
  });

  return {
    isPaid: activeAccessLevel != null,
    appleOriginalTransactionId:
      appleOriginalTransactionId(activeAccessLevel, body.data?.subscriptions) ??
        null,
  };
}

function appleOriginalTransactionId(
  accessLevel: {store?: string; store_original_transaction_id?: string | null} | undefined,
  subscriptions:
    | Array<{store?: string; store_original_transaction_id?: string | null}>
    | undefined,
): string | undefined {
  if (
    accessLevel?.store === "app_store" &&
    accessLevel.store_original_transaction_id != null
  ) {
    return accessLevel.store_original_transaction_id;
  }

  return subscriptions?.find((subscription) =>
    subscription.store === "app_store" &&
    subscription.store_original_transaction_id != null
  )?.store_original_transaction_id ?? undefined;
}

function normalizeAccessLevels(
  accessLevels: AccessLevelCollection | undefined,
): Array<AccessLevel> | undefined {
  if (accessLevels == null) {
    return undefined;
  }

  if (Array.isArray(accessLevels)) {
    return accessLevels;
  }

  return Object.entries(accessLevels).map(([accessLevelID, accessLevel]) => ({
    access_level_id: accessLevel.access_level_id ?? accessLevelID,
    ...accessLevel,
  }));
}

function accessLevelIsActive(accessLevel: AccessLevel): boolean {
  if (accessLevel.is_active === true) {
    return true;
  }

  if (accessLevel.is_active === false) {
    return false;
  }

  const now = Date.now();
  const startsAt = timestamp(accessLevel.starts_at);
  const expiresAt = timestamp(accessLevel.expires_at);

  if (startsAt != null && startsAt > now) {
    return false;
  }

  if (expiresAt != null && expiresAt <= now) {
    return false;
  }

  return true;
}

function timestamp(value: string | null | undefined): number | undefined {
  if (value == null || value.length === 0) {
    return undefined;
  }

  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? undefined : parsed;
}
