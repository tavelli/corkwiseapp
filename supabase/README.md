# Supabase Setup

This app expects a public Supabase Edge Function at:

`POST /functions/v1/analyze-wine-menu`

## Local setup

1. Install the Supabase CLI.
2. From the repo root, initialize Supabase if needed:
   `supabase init`
3. Copy `supabase/functions/.env.example` to `supabase/functions/.env`
4. Fill in:
   - `OPENAI_API_KEY`
   - `OPENAI_MODEL` (optional, defaults to `gpt-4o`)
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
