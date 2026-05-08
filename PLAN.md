# CorkWise Auth, Entitlement, And Backend Access Plan

## Goal

Build a no-login access model that lets CorkWise protect expensive wine-analysis
requests without introducing user accounts.

The app should use a durable app-level identity, anonymous Supabase Auth for
Edge Function access, Adapty for paid entitlement, and Supabase database state
for backend policy decisions. CloudKit and richer usage logging are useful next
steps, but they should not block the first paid/free access implementation.

## Identity Model

- Keychain UUID: durable CorkWise app user id.
- Supabase anonymous auth: request identity for calling Edge Functions.
- Adapty: source of truth for paid entitlement.
- Supabase DB: backend policy state, free scan counts, abuse controls, and
  optional usage analysis.
- CloudKit: optional Apple-side sync for user-owned app data, such as scan
  history and preferences.

## Primary Build: Anonymous Auth + Backend Entitlement Gate

### iOS App

- Add the official Supabase Swift package.
- Add Supabase anon/publishable key support to app configuration.
- Create an app identity service that:
  - loads an existing Keychain UUID
  - creates and stores a UUID if none exists
  - exposes the UUID as the CorkWise app user id
- Create a Supabase auth service that:
  - creates a Supabase client from the configured URL and anon/publishable key
  - silently signs in anonymously when no valid session exists
  - reuses the persisted anonymous session
  - returns the current access token for scan requests
- Update Adapty setup so the Keychain UUID is used as Adapty `customerUserId`.
- Replace the placeholder entitlement manager with real Adapty profile refresh,
  purchase, restore, and active access-level checks.
- Update scan requests so `WineAnalysisService` sends:
  - `Authorization: Bearer <supabase access token>`
  - the Keychain UUID as `appUserId` in the request body or a dedicated header
  - the existing scan payload
- Gate app routing so users without active local Adapty entitlement see the
  paywall, but still rely on the backend as the final authority before analysis.

### Supabase Backend

- Enable anonymous sign-ins in local Supabase config for parity with hosted
  project settings.
- Require JWT verification for `analyze-wine-menu`.
- Add an `app_installations` table keyed by the durable Keychain app user id:
  - `keychain_app_user_id uuid primary key`
  - `supabase_user_id uuid null`
  - `apple_original_transaction_id text null`
  - `created_at timestamptz not null default now()`
  - `updated_at timestamptz not null default now()`
  - `free_scans_used integer not null default 0`
- On every scan request, the Edge Function should:
  - verify the Supabase JWT
  - extract the JWT `sub` as the Supabase anonymous user id
  - validate the Keychain `appUserId`
  - upsert the matching `app_installations` row
  - update `supabase_user_id` to the latest seen Supabase anonymous user id
  - treat Supabase anonymous auth as the request-access identity
  - treat the Keychain app user id as the Adapty entitlement identity
- Add Adapty server API verification in the Edge Function:
  - store the Adapty secret API key in Supabase secrets only
  - check the Adapty profile for `customerUserId = appUserId`
  - require active access level `premium`
  - store `apple_original_transaction_id` when it is available from trusted
    Adapty/server-side purchase data
  - reject unpaid users before calling OpenAI/Gemini
- Return a structured error for unpaid users:
  - HTTP status: `402` or `403`
  - `error: "entitlement_required"`
  - user-facing message: "An active CorkWise subscription is required to scan."
  - `retrySuggested: false`
- Remove full scan-result logging from the Edge Function.
- Do not return provider debug info in production responses.

## Free Scan Policy

Initial implementation should support paid gating first.

If free scans are desired, add them after backend entitlement verification is in
place:

- If Adapty says the user is paid, allow the scan.
- If Adapty says the user is not paid, check
  `app_installations.free_scans_used`.
- If free scans remain, increment `free_scans_used` and allow the scan.
- If no free scans remain, return `entitlement_required`.

Recommended first free-scan policy, if enabled later:

- 1 lifetime free scans per Keychain app user id.
- Count only scan attempts that pass request validation and reach backend policy
  evaluation.
- Store free scan usage in `app_installations`, not on device.
- Increment scans used instead of counting down so the allowed free-scan limit
  can be changed later without migrating existing rows.

## Backlog: Usage Logging

Add lightweight backend usage logs after the entitlement gate is stable.

Purpose:

- debug why a user was allowed or blocked
- measure free versus paid scan usage
- estimate AI cost
- identify abuse patterns
- support future rate limits or free scan policy changes

Suggested table fields:

- id
- created_at
- supabase_auth_user_id
- keychain_app_user_id
- is_paid
- allowed
- decision_reason
- scan_source
- provider
- success
- error_code
- estimated_cost_usd

Do not store uploaded images, full wine-list text, full scan results, or other
unnecessary user content in usage logs.

Usage logging can also track Supabase anonymous user id plus Keychain app user id
pairs for debugging and abuse analysis, but v1 should not hard-bind or reject
requests solely because those ids changed.

## Backlog: CloudKit Sync

CloudKit should be treated as user data sync, not backend authorization.

Possible CloudKit scope:

- sync scan history across the user's Apple devices
- sync taste preferences
- restore local app state after reinstall when the user is signed into iCloud

CloudKit should not be used as the source of truth for:

- paid entitlement
- free scan counts
- backend rate limits
- abuse controls

Those decisions should remain server-side in Adapty and Supabase.

## Testing And Acceptance Criteria

### iOS

- Fresh install creates a Keychain UUID.
- Relaunch reuses the same Keychain UUID.
- App silently creates or reuses a Supabase anonymous session.
- Adapty is identified with the Keychain UUID.
- Scan requests include a Supabase bearer token and Keychain app user id.
- Unpaid users are routed to paywall locally.
- Paid users can reach the scan flow locally.
- Backend entitlement errors are displayed clearly and do not look like generic
  scan failures.

### Supabase

- Unauthenticated requests to `analyze-wine-menu` are rejected.
- Authenticated anonymous requests with a valid Keychain UUID reach the Adapty
  entitlement check.
- Valid scan requests upsert an `app_installations` row for the Keychain UUID.
- The latest Supabase anonymous user id is recorded without enforcing a strict
  one-to-one binding.
- Changing the Supabase anonymous user id or Keychain UUID does not create a
  hard backend identity mismatch in v1.
- Requests without active Adapty `premium` access are rejected before AI calls.
- Requests with active Adapty `premium` access continue to analysis.
- When free scans are enabled, unpaid allowed scans increment
  `free_scans_used`.
- When Adapty returns trusted Apple purchase metadata, the backend stores
  `apple_original_transaction_id`.
- Existing Deno lint, check, and tests pass.

### Release Readiness

- iOS Release build succeeds.
- Supabase function deploy succeeds.
- Adapty secret API key exists only in Supabase secrets.
- Supabase anon/publishable key is present in app configuration.
- No service-role keys or Adapty secret keys are bundled in the app.

## Open Decisions

- Confirm the final Adapty access level id. Current planned default: `premium`.
- Decide whether free scans should ship in the first beta or remain disabled
  until after paid gating is live.
- Decide whether `appUserId` should be sent in the JSON body or a dedicated
  header. Prefer JSON body for explicit request schema and easier tests.
