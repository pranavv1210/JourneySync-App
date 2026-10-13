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
declare profiles_id_type text;
declare users_id_type text;
begin
  if to_regclass('public.users') is not null then
    select format_type(a.atttypid,a.atttypmod) into profiles_id_type
    from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='id' and not a.attisdropped;
    select format_type(a.atttypid,a.atttypmod) into users_id_type
    from pg_attribute a where a.attrelid='public.users'::regclass and a.attname='id' and not a.attisdropped;
    if profiles_id_type = users_id_type then
      execute $sql$
        insert into public.profiles (id, phone, name, bike, avatar_url, created_at)
        select id, phone, name, bike, avatar_url, created_at from public.users
        on conflict (id) do update set
          phone=excluded.phone, name=excluded.name, bike=excluded.bike,
          avatar_url=excluded.avatar_url
      $sql$;
    end if;
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

do $$
declare
  source_expressions text;
  host_id_type text;
begin
  select format_type(attribute.atttypid, attribute.atttypmod)
  into host_id_type
  from pg_attribute attribute
  where attribute.attrelid = 'public.rides'::regclass
    and attribute.attname = 'host_id'
    and not attribute.attisdropped;

  select string_agg(
    format('nullif(%I::text, '''')::%s', column_name, host_id_type),
    ', '
  )
  into source_expressions
  from unnest(array['host_id', 'creator_id', 'user_id', 'leader_id', 'ride_leader_id'])
    as candidate(column_name)
  where exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'rides'
      and column_name = candidate.column_name
  );

  if source_expressions is not null then
    execute format(
      'update public.rides set host_id = coalesce(%s) where host_id is null',
      source_expressions
    );
  end if;
end $$;

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

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'user_id'
  ) then
    update public.ride_members rm
    set member_id = p.id
    from public.profiles p
    where rm.member_id is null and rm.user_id is not null
      and (p.id::text=rm.user_id::text
        or coalesce(to_jsonb(p)->>'auth_user_id','')=rm.user_id::text);
  end if;
end $$;

insert into public.ride_members (ride_id, member_id, role, status)
select r.id, p.id, 'host', 'approved'
from public.rides r
join public.profiles p on p.id::text=r.host_id::text
  or coalesce(to_jsonb(p)->>'auth_user_id','')=r.host_id::text
where r.host_id is not null
on conflict (ride_id, member_id) do update set role = 'host', status = 'approved';

do $$
begin
  if to_regclass('public.participants') is not null then
    insert into public.ride_members (ride_id, member_id, role, status)
    select legacy.ride_id, p.id, 'member', 'approved'
    from public.participants legacy
    join public.profiles p on p.id::text=legacy.user_id::text
      or coalesce(to_jsonb(p)->>'auth_user_id','')=legacy.user_id::text
    where legacy.user_id is not null
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

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'live_locations'
      and column_name = 'user_id'
  ) then
    update public.live_locations location
    set profile_id = p.id
    from public.profiles p
    where location.profile_id is null and location.user_id is not null
      and (p.id::text=location.user_id::text
        or coalesce(to_jsonb(p)->>'auth_user_id','')=location.user_id::text);
  end if;
end $$;

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

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_alerts'
      and column_name = 'user_id'
  ) then
    update public.ride_alerts alert
    set profile_id = p.id
    from public.profiles p
    where alert.profile_id is null and alert.user_id is not null
      and (p.id::text=alert.user_id::text
        or coalesce(to_jsonb(p)->>'auth_user_id','')=alert.user_id::text);
  end if;
end $$;

do $$
declare profile_id_type text;
begin
  select format_type(a.atttypid,a.atttypmod) into profile_id_type
  from pg_attribute a
  where a.attrelid='public.profiles'::regclass
    and a.attname='id' and not a.attisdropped;

  if to_regclass('public.notifications') is null then
    execute format($sql$
      create table public.notifications (
        id uuid primary key default gen_random_uuid(),
        profile_id %s not null references public.profiles(id) on delete cascade,
        ride_id uuid references public.rides(id) on delete cascade,
        type text not null,
        title text not null,
        body text not null default '',
        read_at timestamptz,
        created_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
  end if;

  if to_regclass('public.ride_summaries') is null then
    execute format($sql$
      create table public.ride_summaries (
        ride_id uuid primary key references public.rides(id) on delete cascade,
        host_id %s references public.profiles(id) on delete set null,
        distance_km double precision,
        duration_seconds integer,
        rider_count integer not null default 1,
        route_points jsonb,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
  end if;
end $$;

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
      using (auth.uid()::text = coalesce(to_jsonb(profiles)->>'auth_user_id', id::text))
      with check (auth.uid()::text = coalesce(to_jsonb(profiles)->>'auth_user_id', id::text));
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
