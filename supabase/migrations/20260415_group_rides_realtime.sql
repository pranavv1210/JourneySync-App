-- JourneySync production group rides + realtime schema
-- Run in Supabase SQL editor.

create extension if not exists "pgcrypto";

create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Rider',
  phone text unique,
  bike text not null default 'No bike added',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.rides (
  id uuid primary key default gen_random_uuid(),
  host_id uuid references public.users(id) on delete set null,
  creator_id uuid references public.users(id) on delete set null,
  title text not null,
  start_location text not null,
  end_location text not null,
  status text not null default 'scheduled',
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz,
  max_riders integer
);

alter table if exists public.rides
  add column if not exists host_id uuid references public.users(id) on delete set null,
  add column if not exists creator_id uuid references public.users(id) on delete set null,
  add column if not exists title text,
  add column if not exists start_location text,
  add column if not exists end_location text,
  add column if not exists status text default 'scheduled',
  add column if not exists created_at timestamptz default now(),
  add column if not exists started_at timestamptz,
  add column if not exists ended_at timestamptz,
  add column if not exists max_riders integer;

update public.rides
set host_id = coalesce(host_id, creator_id, user_id, leader_id)
where host_id is null;

create table if not exists public.ride_members (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (ride_id, user_id)
);

insert into public.ride_members (ride_id, user_id)
select r.id, r.host_id
from public.rides r
where r.host_id is not null
on conflict (ride_id, user_id) do nothing;

insert into public.ride_members (ride_id, user_id)
select p.ride_id, p.user_id
from public.participants p
on conflict (ride_id, user_id) do nothing;

create table if not exists public.live_locations (
  ride_id uuid not null references public.rides(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  speed_mps double precision,
  heading double precision,
  battery text,
  signal text,
  updated_at timestamptz not null default now(),
  primary key (ride_id, user_id)
);

create index if not exists idx_live_locations_ride_updated
  on public.live_locations(ride_id, updated_at desc);

create table if not exists public.ride_routes (
  ride_id uuid primary key references public.rides(id) on delete cascade,
  host_id uuid references public.users(id) on delete set null,
  start_label text not null,
  end_label text not null,
  stops jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.ride_members enable row level security;
alter table public.live_locations enable row level security;
alter table public.ride_routes enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_members'
      and policyname = 'ride_members_all'
  ) then
    create policy ride_members_all on public.ride_members
      for all using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_locations'
      and policyname = 'live_locations_all'
  ) then
    create policy live_locations_all on public.live_locations
      for all using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_routes'
      and policyname = 'ride_routes_all'
  ) then
    create policy ride_routes_all on public.ride_routes
      for all using (true) with check (true);
  end if;
end $$;

alter publication supabase_realtime add table public.live_locations;
