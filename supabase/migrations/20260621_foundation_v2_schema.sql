-- JourneySync V2 foundation schema.
-- Safe forward migration: creates canonical tables/columns and backfills from
-- legacy structures without dropping data.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key,
  phone text unique,
  name text not null default 'Rider',
  bike text not null default 'No bike added',
  avatar_url text,
  active_ride_id uuid,
  created_at timestamptz not null default now()
);

do $$
begin
  if to_regclass('public.users') is not null then
    insert into public.profiles (id, phone, name, bike, avatar_url, created_at)
    select id, phone, name, bike, avatar_url, created_at
    from public.users
    on conflict (id) do update set
      phone = excluded.phone,
      name = excluded.name,
      bike = excluded.bike,
      avatar_url = excluded.avatar_url;
  end if;
end $$;

alter table if exists public.rides
  add column if not exists host_id uuid references public.profiles(id) on delete set null,
  add column if not exists status text not null default 'scheduled',
  add column if not exists started_at timestamptz,
  add column if not exists ended_at timestamptz,
  add column if not exists max_riders integer,
  add column if not exists start_lat double precision,
  add column if not exists start_lng double precision,
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision;

alter table if exists public.profiles
  add column if not exists active_ride_id uuid references public.rides(id) on delete set null;

update public.rides
set host_id = coalesce(host_id, creator_id, user_id, leader_id)
where host_id is null;

create table if not exists public.ride_members (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'approved',
  created_at timestamptz not null default now(),
  unique (ride_id, member_id)
);

alter table if exists public.ride_members
  add column if not exists member_id uuid references public.profiles(id) on delete cascade,
  add column if not exists role text not null default 'member',
  add column if not exists status text not null default 'approved';

update public.ride_members
set member_id = user_id
where member_id is null and user_id is not null;

insert into public.ride_members (ride_id, member_id, role, status)
select id, host_id, 'host', 'approved'
from public.rides
where host_id is not null
on conflict (ride_id, member_id) do update set role = 'host', status = 'approved';

do $$
begin
  if to_regclass('public.participants') is not null then
    insert into public.ride_members (ride_id, member_id, role, status)
    select ride_id, user_id, 'member', 'approved'
    from public.participants
    where user_id is not null
    on conflict (ride_id, member_id) do nothing;
  end if;
end $$;

create table if not exists public.live_locations (
  ride_id uuid not null references public.rides(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  speed double precision,
  heading double precision,
  battery text,
  signal text,
  user_name text not null default 'Rider',
  bike_name text not null default 'No bike added',
  is_leader boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table if exists public.live_locations
  add column if not exists profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists speed double precision,
  add column if not exists user_name text not null default 'Rider',
  add column if not exists bike_name text not null default 'No bike added',
  add column if not exists is_leader boolean not null default false;

update public.live_locations
set profile_id = user_id
where profile_id is null and user_id is not null;

update public.live_locations
set speed = speed_mps
where speed is null and speed_mps is not null;

create unique index if not exists live_locations_ride_profile_uidx
  on public.live_locations(ride_id, profile_id)
  where profile_id is not null;

create table if not exists public.ride_routes (
  ride_id uuid primary key references public.rides(id) on delete cascade,
  host_id uuid references public.profiles(id) on delete set null,
  start_label text not null default '',
  end_label text not null default '',
  stops jsonb not null default '[]'::jsonb,
  destination_lat double precision,
  destination_lng double precision,
  route_points jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.ride_alerts (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  user_name text not null default 'Rider',
  type text not null default 'SOS',
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

alter table if exists public.ride_alerts
  add column if not exists profile_id uuid references public.profiles(id) on delete set null;

update public.ride_alerts
set profile_id = user_id
where profile_id is null and user_id is not null;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  ride_id uuid references public.rides(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.ride_summaries (
  ride_id uuid primary key references public.rides(id) on delete cascade,
  host_id uuid references public.profiles(id) on delete set null,
  distance_km double precision,
  duration_seconds integer,
  rider_count integer not null default 1,
  route_points jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.ride_members enable row level security;
alter table public.live_locations enable row level security;
alter table public.ride_routes enable row level security;
alter table public.ride_alerts enable row level security;
alter table public.notifications enable row level security;
alter table public.ride_summaries enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_owner_all'
  ) then
    create policy profiles_owner_all on public.profiles
      for all to authenticated
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_members'
      and policyname = 'ride_members_authenticated_all'
  ) then
    create policy ride_members_authenticated_all on public.ride_members
      for all to authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'live_locations'
      and policyname = 'live_locations_authenticated_all'
  ) then
    create policy live_locations_authenticated_all on public.live_locations
      for all to authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_routes'
      and policyname = 'ride_routes_authenticated_all'
  ) then
    create policy ride_routes_authenticated_all on public.ride_routes
      for all to authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_alerts'
      and policyname = 'ride_alerts_authenticated_all'
  ) then
    create policy ride_alerts_authenticated_all on public.ride_alerts
      for all to authenticated using (true) with check (true);
  end if;
end $$;
