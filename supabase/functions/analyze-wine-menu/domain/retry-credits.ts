import { restHeaders, restURL } from "./rest.ts";
import { RequestError } from "./types.ts";

export type RetryCredit = {
  id: string;
};

export async function availableRetryCredit(
  appUserId: string,
): Promise<RetryCredit | null> {
  const query = new URL(`${restURL()}/analysis_retry_credits`);
  query.searchParams.set("select", "id");
  query.searchParams.set("keychain_app_user_id", `eq.${appUserId}`);
  query.searchParams.set("used_at", "is.null");
  query.searchParams.set("order", "created_at.asc");
  query.searchParams.set("limit", "1");

  const response = await fetch(query, {
    method: "GET",
    headers: restHeaders(),
  });

  if (response.ok === false) {
    throw new RequestError(
      500,
      "analysis_failed",
      "Something went wrong while preparing the scan.",
      true,
    );
  }

  const [credit] = await response.json() as Array<{ id: string }>;
  return credit == null ? null : { id: credit.id };
}

export async function consumeRetryCredit(creditId: string): Promise<boolean> {
  const response = await fetch(
    `${restURL()}/analysis_retry_credits?id=eq.${creditId}&used_at=is.null`,
    {
      method: "PATCH",
      headers: restHeaders({
        Prefer: "return=representation",
      }),
      body: JSON.stringify({
        used_at: new Date().toISOString(),
      }),
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

  const updatedRows = await response.json() as Array<{ id: string }>;
  return updatedRows.length > 0;
}
