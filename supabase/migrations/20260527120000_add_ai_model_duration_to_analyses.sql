alter table public.analyses
  add column if not exists ai_model_duration_milliseconds integer null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'analyses_ai_model_duration_milliseconds_check'
  ) then
    alter table public.analyses
      add constraint analyses_ai_model_duration_milliseconds_check
      check (
        ai_model_duration_milliseconds is null
        or ai_model_duration_milliseconds >= 0
      );
  end if;
end $$;
