# Supabase Setup

## Deployment

### prod

npx supabase functions deploy analyze-wine-menu

### local

npx supabase functions serve analyze-wine-menu --env-file functions/.env

This app expects a public Supabase Edge Function at:

`POST /functions/v1/analyze-wine-menu`

## Local setup

1. Install the Supabase CLI.
2. From the repo root, initialize Supabase if needed:
   `supabase init`
3. Copy `supabase/functions/.env.example` to `supabase/functions/.env`
4. Fill in:
   - `MODEL_PROVIDER` as `openai` or `gemini`
   - `OPENAI_API_KEY` when using OpenAI
   - `OPENAI_MODEL` (optional, defaults to `gpt-4o`)
   - `OPENAI_REASONING_EFFORT` (optional, set to `off` to disable)
   - `OPENAI_TEXT_VERBOSITY` (optional, set to `off` to disable)
   - `GEMINI_API_KEY` when using Gemini
   - `GEMINI_MODEL` (optional, defaults to `gemini-2.5-flash`)
5. Run the function locally:
   `supabase functions serve analyze-wine-menu --env-file supabase/functions/.env`

Local URL:

`http://127.0.0.1:54321/functions/v1/analyze-wine-menu`

## Deploy

1. Link your local project:
   `supabase link --project-ref YOUR_PROJECT_REF`
2. Set production secrets:
   `supabase secrets set --env-file supabase/functions/.env`
3. Deploy:
   `supabase functions deploy analyze-wine-menu`

## iOS app config

Set `CorkWiseSupabaseBaseURL` in the iOS target to your base project URL, for example:

`https://YOUR_PROJECT_REF.supabase.co`

## Provider design

The Edge Function keeps one stable app-facing endpoint and swaps model providers behind the function boundary.

- `MODEL_PROVIDER=openai` uses `providers/openai.ts`
- `MODEL_PROVIDER=gemini` uses `providers/gemini.ts`
- Both providers normalize into the same `WineScanResult` response shape before returning to iOS
- Debug token cost estimates come from provider-local pricing constants in `providers/openai.ts` and `providers/gemini.ts`

## Request inputs

The analysis endpoint accepts either a file attachment or a menu URL.

Attachment input:

```json
{
  "attachment": {
    "base64Data": "BASE64_IMAGE_OR_PDF",
    "mimeType": "image/jpeg",
    "filename": "menu.jpg"
  },
  "purchaseMode": "bottle",
  "categoryPreference": "anything",
  "userPreferences": {
    "preferredStyles": ["crisp whites"],
    "favoriteVarietals": [],
    "choiceStyle": "value",
    "tone": "standard"
  }
}
```

URL input:

```json
{
  "menuUrl": "https://example.com/menu",
  "purchaseMode": "bottle",
  "categoryPreference": "anything",
  "userPreferences": {
    "preferredStyles": ["crisp whites"],
    "favoriteVarietals": [],
    "choiceStyle": "value",
    "tone": "standard"
  }
}
```

Menu URL analysis requires `MODEL_PROVIDER=gemini`. The Gemini provider enables URL context with `tools: [{ "url_context": {} }]`.
