create table if not exists public.app_installations (
  keychain_app_user_id uuid primary key,
  supabase_user_id uuid null,
  apple_original_transaction_id text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  free_scans_used integer not null default 0 check (free_scans_used >= 0)
);

alter table public.app_installations enable row level security;

create index if not exists app_installations_supabase_user_id_idx
  on public.app_installations (supabase_user_id);

create index if not exists app_installations_apple_original_transaction_id_idx
  on public.app_installations (apple_original_transaction_id)
  where apple_original_transaction_id is not null;

create or replace function public.free_scan_allowance(
  p_keychain_app_user_id uuid,
  p_free_scan_limit integer
)
returns table (
  allowed boolean,
  free_scans_used integer
)
language sql
security definer
set search_path = public
as $$
  select
    p_free_scan_limit > 0 and ai.free_scans_used < p_free_scan_limit,
    ai.free_scans_used
  from public.app_installations ai
  where ai.keychain_app_user_id = p_keychain_app_user_id;
$$;

create or replace function public.consume_free_scan(
  p_keychain_app_user_id uuid,
  p_free_scan_limit integer
)
returns table (
  allowed boolean,
  free_scans_used integer
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_free_scan_limit <= 0 then
    return query
    select false, ai.free_scans_used
    from public.app_installations ai
    where ai.keychain_app_user_id = p_keychain_app_user_id;
    return;
  end if;

  return query
  update public.app_installations ai
  set
    free_scans_used = ai.free_scans_used + 1,
    updated_at = now()
  where
    ai.keychain_app_user_id = p_keychain_app_user_id
    and ai.free_scans_used < p_free_scan_limit
  returning true, ai.free_scans_used;

  if not found then
    return query
    select false, ai.free_scans_used
    from public.app_installations ai
    where ai.keychain_app_user_id = p_keychain_app_user_id;
  end if;
end;
$$;
