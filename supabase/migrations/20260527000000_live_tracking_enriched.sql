-- ============================================================
-- JourneySync: Enrich live_locations for real-time rider tracking
-- Run this in Supabase SQL Editor.
-- ============================================================

-- 1) Add enriched columns to live_locations
--    (user_name, bike_name avoid a JOIN when pushing realtime updates)
alter table if exists public.live_locations
  add column if not exists user_name  text    not null default 'Rider',
  add column if not exists bike_name  text    not null default 'No bike added',
  add column if not exists is_leader  boolean not null default false;

-- Rename speed_mps → speed for brevity (add new column, keep old for compat)
alter table if exists public.live_locations
  add column if not exists speed double precision;

-- Back-fill speed from speed_mps where it exists
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'live_locations'
      and column_name = 'speed_mps'
  ) then
    update public.live_locations
    set speed = speed_mps
    where speed is null and speed_mps is not null;
  end if;
end $$;

-- 2) Ensure ride_alerts table exists with full schema
create table if not exists public.ride_alerts (
  id         uuid primary key default gen_random_uuid(),
  ride_id    uuid not null references public.rides(id) on delete cascade,
  user_id    uuid not null references public.users(id) on delete cascade,
  user_name  text not null default 'Rider',
  type       text not null default 'SOS',
  latitude   double precision,
  longitude  double precision,
  created_at timestamptz not null default now()
);

create index if not exists idx_ride_alerts_ride_created
  on public.ride_alerts(ride_id, created_at desc);

alter table if exists public.ride_alerts enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename  = 'ride_alerts'
      and policyname = 'ride_alerts_all'
  ) then
    create policy ride_alerts_all on public.ride_alerts
      for all using (true) with check (true);
  end if;
end $$;

-- 3) Ensure ride_routes has destination lat/lng columns (for route sync)
alter table if exists public.ride_routes
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision,
  add column if not exists route_points     jsonb;

-- 4) Publish all relevant tables to Supabase Realtime
--    (idempotent – safe to run even if already added)
do $$
begin
  -- live_locations
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'live_locations'
  ) then
    alter publication supabase_realtime add table public.live_locations;
  end if;

  -- ride_alerts
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'ride_alerts'
  ) then
    alter publication supabase_realtime add table public.ride_alerts;
  end if;

  -- ride_routes
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'ride_routes'
  ) then
    alter publication supabase_realtime add table public.ride_routes;
  end if;
end $$;
