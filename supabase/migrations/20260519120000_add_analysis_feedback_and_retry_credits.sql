create table if not exists public.analyses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz null,
  supabase_auth_user_id uuid null,
  keychain_app_user_id uuid not null references public.app_installations(keychain_app_user_id) on delete cascade,
  is_paid boolean not null default false,
  allowed boolean not null default false,
  decision_reason text not null,
  access_source text not null check (access_source in ('paid', 'free_scan', 'retry_credit', 'blocked')),
  scan_source text null check (scan_source in ('attachment', 'url')),
  attachment_count integer null check (attachment_count is null or attachment_count >= 0),
  purchase_mode text null,
  category_preference text null,
  build_configuration text null,
  provider text null,
  model_version text null,
  prompt_version text null,
  success boolean null,
  error_code text null,
  estimated_cost_usd numeric null,
  input_tokens integer null check (input_tokens is null or input_tokens >= 0),
  output_tokens integer null check (output_tokens is null or output_tokens >= 0),
  free_scan_used boolean not null default false,
  retry_credit_used_id uuid null,
  result_payload jsonb null
);

alter table public.analyses enable row level security;

create index if not exists analyses_keychain_app_user_id_idx
  on public.analyses (keychain_app_user_id, created_at desc);

create index if not exists analyses_supabase_auth_user_id_idx
  on public.analyses (supabase_auth_user_id, created_at desc)
  where supabase_auth_user_id is not null;

create table if not exists public.analysis_feedback (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  supabase_auth_user_id uuid null,
  keychain_app_user_id uuid not null references public.app_installations(keychain_app_user_id) on delete cascade,
  analysis_id uuid null references public.analyses(id) on delete set null,
  rating text not null check (rating in ('useful', 'not_useful')),
  comment text null,
  source text not null default 'result_end_card',
  free_scan_used boolean null,
  retry_granted boolean not null default false
);

alter table public.analysis_feedback enable row level security;

create index if not exists analysis_feedback_analysis_id_idx
  on public.analysis_feedback (analysis_id);

create index if not exists analysis_feedback_keychain_app_user_id_idx
  on public.analysis_feedback (keychain_app_user_id, created_at desc);

create table if not exists public.analysis_retry_credits (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  supabase_auth_user_id uuid null,
  keychain_app_user_id uuid not null references public.app_installations(keychain_app_user_id) on delete cascade,
  feedback_id uuid references public.analysis_feedback(id) on delete cascade,
  reason text not null default 'negative_feedback',
  used_at timestamptz null
);

alter table public.analysis_retry_credits enable row level security;

create index if not exists analysis_retry_credits_available_idx
  on public.analysis_retry_credits (keychain_app_user_id, created_at)
  where used_at is null;

create index if not exists analysis_retry_credits_feedback_id_idx
  on public.analysis_retry_credits (feedback_id)
  where feedback_id is not null;
