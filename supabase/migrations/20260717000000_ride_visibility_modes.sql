alter table if exists public.rides
  add column if not exists ride_visibility text not null default 'public',
  add column if not exists ride_mode text not null default 'group';

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'rides_ride_visibility_check'
  ) then
    alter table public.rides
      add constraint rides_ride_visibility_check
      check (ride_visibility in ('public', 'private'))
      not valid;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'rides_ride_mode_check'
  ) then
    alter table public.rides
      add constraint rides_ride_mode_check
      check (ride_mode in ('instant', 'group', 'solo'))
      not valid;
  end if;
end $$;

create index if not exists rides_radar_public_active_idx
  on public.rides (ride_visibility, status, created_at desc)
  where ride_visibility = 'public' and status in ('active', 'live');
