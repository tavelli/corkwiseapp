## Backlog: Consolidate Scan Page Limit

Use a single shared page-limit constant set to 5 for wine-list scan image flows.

- Add one iOS source of truth for the max scan page count.
- Use it for camera capture limits, camera page-limit copy, photo picker `maxSelectionCount`, and photo item processing.
- Update iOS attachment preparation and request validation to allow 5 images.
- Update Supabase request validation to allow 5 attachments and revise the related error copy.
- Keep generated localization-symbol usage for camera page-limit text.

Acceptance criteria:

- Camera and photo picker both allow up to 5 pages.
- 5 selected/captured JPEG pages can be prepared, validated, and submitted.
- 6 attachments are rejected by client and backend validation.
- iOS simulator, generic iOS, and Supabase request validation tests pass.

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
