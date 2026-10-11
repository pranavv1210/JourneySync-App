-- Fix ride creation on projects where the rides table was created before the
-- canonical group-ride schema added end_location.

alter table if exists public.rides
  add column if not exists end_location text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rides'
      and column_name = 'destination'
  ) then
    execute 'update public.rides set end_location = coalesce(end_location, destination, '''') where end_location is null';
  else
    update public.rides
    set end_location = ''
    where end_location is null;
  end if;
end $$;
