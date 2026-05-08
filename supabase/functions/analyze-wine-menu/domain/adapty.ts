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
      store?: string;
      store_original_transaction_id?: string | null;
    }>;
    paid_access_levels?: Array<{
      access_level_id?: string;
      is_active?: boolean;
      store?: string;
      store_original_transaction_id?: string | null;
    }>;
    subscriptions?: Array<{
      store?: string;
      store_original_transaction_id?: string | null;
    }>;
  };
};

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
  const accessLevels = body.data?.access_levels ?? body.data?.paid_access_levels;
  const activeAccessLevel = accessLevels?.find((accessLevel) =>
    accessLevel.access_level_id === ADAPTY_ACCESS_LEVEL_ID &&
    accessLevel.is_active === true
  );

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
