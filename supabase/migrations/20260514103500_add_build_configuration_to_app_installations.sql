alter table public.app_installations
add column if not exists build_configuration text null;
