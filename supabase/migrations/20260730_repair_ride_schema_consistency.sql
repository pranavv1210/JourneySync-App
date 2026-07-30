-- Repair partially migrated JourneySync databases so Flutter and Supabase use
-- the same canonical ride schema.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key,
  auth_user_id uuid unique,
  phone text,
  name text not null default 'Rider',
  bike text not null default 'No bike added',
  avatar_url text,
  active_ride_id uuid,
  garage_bikes jsonb not null default '[]'::jsonb,
  active_bike_id text,
  last_seen_at timestamptz,
  fcm_token text,
  push_platform text,
  push_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.profiles
  add column if not exists auth_user_id uuid,
  add column if not exists phone text,
  add column if not exists name text not null default 'Rider',
  add column if not exists bike text not null default 'No bike added',
  add column if not exists avatar_url text,
  add column if not exists active_ride_id uuid,
  add column if not exists garage_bikes jsonb not null default '[]'::jsonb,
  add column if not exists active_bike_id text,
  add column if not exists last_seen_at timestamptz,
  add column if not exists fcm_token text,
  add column if not exists push_platform text,
  add column if not exists push_updated_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if to_regclass('public.users') is not null then
    begin
      insert into public.profiles (id, phone, name, bike, avatar_url, created_at)
      select id, phone, coalesce(nullif(name, ''), 'Rider'),
             coalesce(nullif(bike, ''), 'No bike added'), avatar_url,
             coalesce(created_at, now())
      from public.users
      on conflict (id) do update set
        phone = coalesce(public.profiles.phone, excluded.phone),
        name = coalesce(nullif(public.profiles.name, ''), excluded.name),
        bike = coalesce(nullif(public.profiles.bike, ''), excluded.bike),
        avatar_url = coalesce(public.profiles.avatar_url, excluded.avatar_url);
    exception
      when foreign_key_violation then null;
    end;
  end if;
end $$;

do $$
begin
  if to_regclass('public.rides') is null then
    create table public.rides (
      id uuid primary key default gen_random_uuid(),
      host_id uuid,
      title text not null default 'Ride',
      start_location text not null default 'Current location',
      end_location text not null default '',
      status text not null default 'scheduled',
      created_at timestamptz not null default now(),
      started_at timestamptz,
      ended_at timestamptz,
      max_riders integer,
      ride_visibility text not null default 'public',
      ride_mode text not null default 'group',
      description text,
      briefing text,
      alert_status text,
      start_lat double precision,
      start_lng double precision,
      destination_lat double precision,
      destination_lng double precision
    );
  end if;
end $$;

alter table if exists public.rides
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists host_id uuid,
  add column if not exists title text not null default 'Ride',
  add column if not exists start_location text not null default 'Current location',
  add column if not exists end_location text not null default '',
  add column if not exists status text not null default 'scheduled',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists started_at timestamptz,
  add column if not exists ended_at timestamptz,
  add column if not exists max_riders integer,
  add column if not exists ride_visibility text not null default 'public',
  add column if not exists ride_mode text not null default 'group',
  add column if not exists description text,
  add column if not exists briefing text,
  add column if not exists alert_status text,
  add column if not exists start_lat double precision,
  add column if not exists start_lng double precision,
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision;

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rides' and column_name = 'name'
  ) then
    update public.rides
    set title = coalesce(nullif(title, ''), nullif(name, ''), 'Ride');
  else
    update public.rides
    set title = coalesce(nullif(title, ''), 'Ride');
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'rides' and column_name = 'destination'
  ) then
    update public.rides
    set end_location = coalesce(nullif(end_location, ''), nullif(destination, ''), '');
  else
    update public.rides
    set end_location = coalesce(end_location, '');
  end if;

  update public.rides
  set start_location = coalesce(nullif(start_location, ''), 'Current location'),
      status = coalesce(nullif(status, ''), 'scheduled'),
      created_at = coalesce(created_at, now()),
      ride_visibility = case
        when lower(coalesce(ride_visibility, 'public')) = 'private' then 'private'
        else 'public'
      end,
      ride_mode = case
        when lower(coalesce(ride_mode, 'group')) in ('instant', 'group', 'solo')
          then lower(ride_mode)
        else 'group'
      end;
end $$;

do $$
declare
  source_columns text;
begin
  select string_agg(format('%I', column_name), ', ')
  into source_columns
  from unnest(array['host_id', 'creator_id', 'leader_id', 'ride_leader_id', 'user_id'])
    as candidate(column_name)
  where exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rides'
      and column_name = candidate.column_name
  );

  if source_columns is not null then
    execute format(
      'update public.rides set host_id = coalesce(%s) where host_id is null',
      source_columns
    );
  end if;
end $$;

do $$
begin
  begin
    insert into public.profiles (id, auth_user_id, name, bike)
    select distinct host_id, host_id, 'Rider', 'No bike added'
    from public.rides
    where host_id is not null
    on conflict (id) do nothing;
  exception
    when foreign_key_violation then null;
  end;
end $$;

create table if not exists public.ride_members (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'approved',
  presence_status text default 'offline',
  last_seen_at timestamptz,
  app_state text,
  created_at timestamptz not null default now(),
  unique (ride_id, member_id)
);

alter table if exists public.ride_members
  add column if not exists member_id uuid,
  add column if not exists role text not null default 'member',
  add column if not exists status text not null default 'approved',
  add column if not exists presence_status text default 'offline',
  add column if not exists last_seen_at timestamptz,
  add column if not exists app_state text,
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ride_members' and column_name = 'user_id'
  ) then
    update public.ride_members
    set member_id = user_id
    where member_id is null and user_id is not null;
  end if;
end $$;

delete from public.ride_members a
using public.ride_members b
where a.ctid < b.ctid
  and a.ride_id = b.ride_id
  and a.member_id is not null
  and a.member_id = b.member_id;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_ride_id_member_id_key'
  ) then
    alter table public.ride_members
      add constraint ride_members_ride_id_member_id_key unique (ride_id, member_id);
  end if;
end $$;

insert into public.ride_members (ride_id, member_id, role, status)
select id, host_id, 'host', 'approved'
from public.rides
where host_id is not null
  and exists (
    select 1
    from public.profiles p
    where p.id = public.rides.host_id
  )
on conflict (ride_id, member_id) do update set role = 'host', status = 'approved';

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

alter table if exists public.ride_routes
  add column if not exists ride_id uuid,
  add column if not exists host_id uuid,
  add column if not exists start_label text not null default '',
  add column if not exists end_label text not null default '',
  add column if not exists stops jsonb not null default '[]'::jsonb,
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision,
  add column if not exists route_points jsonb,
  add column if not exists updated_at timestamptz not null default now();

delete from public.ride_routes a
using public.ride_routes b
where a.ctid < b.ctid
  and a.ride_id is not null
  and a.ride_id = b.ride_id;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_routes'::regclass
      and conname = 'ride_routes_ride_id_key'
  ) then
    alter table public.ride_routes
      add constraint ride_routes_ride_id_key unique (ride_id);
  end if;
end $$;

create table if not exists public.live_locations (
  ride_id uuid not null references public.rides(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  latitude double precision not null,
  longitude double precision not null,
  speed double precision,
  speed_mps double precision,
  heading double precision,
  battery text,
  signal text,
  user_name text not null default 'Rider',
  bike_name text not null default 'No bike added',
  is_leader boolean not null default false,
  app_state text default 'tracking',
  accuracy double precision,
  queued_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table if exists public.live_locations
  add column if not exists profile_id uuid,
  add column if not exists speed double precision,
  add column if not exists speed_mps double precision,
  add column if not exists heading double precision,
  add column if not exists battery text,
  add column if not exists signal text,
  add column if not exists user_name text not null default 'Rider',
  add column if not exists bike_name text not null default 'No bike added',
  add column if not exists is_leader boolean not null default false,
  add column if not exists app_state text default 'tracking',
  add column if not exists accuracy double precision,
  add column if not exists queued_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'live_locations' and column_name = 'user_id'
  ) then
    update public.live_locations
    set profile_id = user_id
    where profile_id is null and user_id is not null;
  end if;

  update public.live_locations
  set speed = coalesce(speed, speed_mps);
end $$;

delete from public.live_locations a
using public.live_locations b
where a.ctid < b.ctid
  and a.ride_id = b.ride_id
  and a.profile_id is not null
  and a.profile_id = b.profile_id;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.live_locations'::regclass
      and conname = 'live_locations_ride_id_profile_id_key'
  ) then
    alter table public.live_locations
      add constraint live_locations_ride_id_profile_id_key unique (ride_id, profile_id);
  end if;
end $$;

create table if not exists public.ride_alerts (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  profile_id uuid references public.profiles(id) on delete set null,
  user_name text not null default 'Rider',
  type text not null default 'SOS',
  message text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now()
);

alter table if exists public.ride_alerts
  add column if not exists profile_id uuid,
  add column if not exists user_name text not null default 'Rider',
  add column if not exists type text not null default 'SOS',
  add column if not exists message text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ride_alerts' and column_name = 'user_id'
  ) then
    update public.ride_alerts
    set profile_id = user_id
    where profile_id is null and user_id is not null;
  end if;
end $$;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references public.profiles(id) on delete cascade,
  ride_id uuid references public.rides(id) on delete cascade,
  type text,
  title text not null default 'JourneySync',
  body text not null default '',
  category text not null default 'system',
  payload jsonb not null default '{}'::jsonb,
  read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table if exists public.notifications
  add column if not exists profile_id uuid,
  add column if not exists ride_id uuid,
  add column if not exists type text,
  add column if not exists title text not null default 'JourneySync',
  add column if not exists body text not null default '',
  add column if not exists category text not null default 'system',
  add column if not exists payload jsonb not null default '{}'::jsonb,
  add column if not exists read boolean not null default false,
  add column if not exists read_at timestamptz,
  add column if not exists created_at timestamptz not null default now();

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

alter table if exists public.ride_summaries
  add column if not exists host_id uuid,
  add column if not exists distance_km double precision,
  add column if not exists duration_seconds integer,
  add column if not exists rider_count integer not null default 1,
  add column if not exists route_points jsonb,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists profiles_auth_user_id_unique_idx
  on public.profiles (auth_user_id)
  where auth_user_id is not null;

create unique index if not exists profiles_phone_unique_idx
  on public.profiles (phone)
  where phone is not null and phone <> '';

create index if not exists rides_host_status_created_idx
  on public.rides (host_id, status, created_at desc);

create index if not exists rides_radar_public_active_idx
  on public.rides (ride_visibility, status, created_at desc)
  where ride_visibility = 'public' and status in ('active', 'live');

create index if not exists ride_members_member_status_idx
  on public.ride_members (member_id, status, created_at desc);

create index if not exists ride_members_radar_ride_idx
  on public.ride_members (ride_id);

create index if not exists ride_routes_host_updated_idx
  on public.ride_routes (host_id, updated_at desc)
  where host_id is not null;

create index if not exists live_locations_profile_updated_idx
  on public.live_locations (profile_id, updated_at desc)
  where profile_id is not null;

create index if not exists ride_alerts_profile_created_idx
  on public.ride_alerts (profile_id, created_at desc)
  where profile_id is not null;

create index if not exists notifications_profile_created_idx
  on public.notifications (profile_id, created_at desc);

create index if not exists notifications_profile_unread_idx
  on public.notifications (profile_id, read)
  where read = false;

create index if not exists ride_summaries_host_created_idx
  on public.ride_summaries (host_id, created_at desc)
  where host_id is not null;

alter table public.profiles enable row level security;
alter table public.rides enable row level security;
alter table public.ride_members enable row level security;
alter table public.ride_routes enable row level security;
alter table public.live_locations enable row level security;
alter table public.ride_alerts enable row level security;
alter table public.notifications enable row level security;
alter table public.ride_summaries enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
      and policyname = 'profiles_authenticated_all'
  ) then
    create policy profiles_authenticated_all on public.profiles
      for all to authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'rides'
      and policyname = 'rides_authenticated_all'
  ) then
    create policy rides_authenticated_all on public.rides
      for all to authenticated using (true) with check (true);
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
    where schemaname = 'public' and tablename = 'ride_routes'
      and policyname = 'ride_routes_authenticated_all'
  ) then
    create policy ride_routes_authenticated_all on public.ride_routes
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
    where schemaname = 'public' and tablename = 'ride_alerts'
      and policyname = 'ride_alerts_authenticated_all'
  ) then
    create policy ride_alerts_authenticated_all on public.ride_alerts
      for all to authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'notifications_authenticated_all'
  ) then
    create policy notifications_authenticated_all on public.notifications
      for all to authenticated using (true) with check (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_summaries'
      and policyname = 'ride_summaries_authenticated_all'
  ) then
    create policy ride_summaries_authenticated_all on public.ride_summaries
      for all to authenticated using (true) with check (true);
  end if;
end $$;

do $$
begin
  begin
    alter publication supabase_realtime add table public.rides;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.ride_members;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.ride_routes;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.live_locations;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.ride_alerts;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.notifications;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

alter table if exists public.rides replica identity full;
alter table if exists public.ride_members replica identity full;
alter table if exists public.ride_routes replica identity full;
alter table if exists public.live_locations replica identity full;
alter table if exists public.ride_alerts replica identity full;
alter table if exists public.notifications replica identity full;
