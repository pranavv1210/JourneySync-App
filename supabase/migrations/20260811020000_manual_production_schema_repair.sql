-- Manual production repair for JourneySync databases with legacy bigint profiles.
-- Run this in Supabase SQL Editor if older migrations fail with uuid/bigint
-- profile ID mismatches.

create extension if not exists "pgcrypto";

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

create unique index if not exists profiles_auth_user_id_unique_idx
  on public.profiles (auth_user_id)
  where auth_user_id is not null;

do $$
declare
  profile_id_type text;
  feedback_user_id_type text;
  feedback_rows bigint := 0;
begin
  select format_type(a.atttypid, a.atttypmod)
    into profile_id_type
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and a.attname = 'id'
    and not a.attisdropped;

  if profile_id_type is null then
    raise exception 'public.profiles.id must exist before running this repair';
  end if;

  if to_regclass('public.rides') is null then
    execute format($sql$
      create table public.rides (
        id uuid primary key default gen_random_uuid(),
        profile_id %s,
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
      )
    $sql$, profile_id_type);
  else
    execute format('alter table public.rides add column if not exists profile_id %s', profile_id_type);
  end if;

  if to_regclass('public.ride_routes') is null then
    execute format($sql$
      create table public.ride_routes (
        ride_id uuid primary key references public.rides(id) on delete cascade,
        profile_id %s references public.profiles(id) on delete set null,
        start_label text not null default '',
        end_label text not null default '',
        stops jsonb not null default '[]'::jsonb,
        distance_km double precision,
        duration_minutes integer,
        updated_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
  else
    execute format('alter table public.ride_routes add column if not exists profile_id %s', profile_id_type);
  end if;

  execute format($sql$
    create table if not exists public.app_feedback (
      id uuid primary key default gen_random_uuid(),
      user_id %s not null references public.profiles(id) on delete cascade,
      auth_user_id uuid,
      rating integer not null check (rating between 1 and 5),
      improvement_feedback text,
      app_version text not null default '',
      platform text not null default '',
      created_at timestamptz not null default now()
    )
  $sql$, profile_id_type);

  select format_type(a.atttypid, a.atttypmod)
    into feedback_user_id_type
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'app_feedback'
    and a.attname = 'user_id'
    and not a.attisdropped;

  execute 'select count(*) from public.app_feedback' into feedback_rows;

  if feedback_user_id_type is distinct from profile_id_type then
    if feedback_rows > 0 then
      raise exception 'public.app_feedback.user_id is %, but public.profiles.id is %. Resolve existing feedback rows before changing the column type.',
        feedback_user_id_type, profile_id_type;
    end if;

    alter table public.app_feedback
      drop constraint if exists app_feedback_user_id_fkey;

    execute format(
      'alter table public.app_feedback alter column user_id type %s using null',
      profile_id_type
    );

    alter table public.app_feedback
      alter column user_id set not null;
  end if;
end $$;

alter table if exists public.rides
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

alter table if exists public.ride_routes
  add column if not exists start_label text not null default '',
  add column if not exists end_label text not null default '',
  add column if not exists stops jsonb not null default '[]'::jsonb,
  add column if not exists distance_km double precision,
  add column if not exists duration_minutes integer,
  add column if not exists updated_at timestamptz not null default now();

alter table public.app_feedback
  add column if not exists auth_user_id uuid,
  add column if not exists improvement_feedback text,
  add column if not exists app_version text not null default '',
  add column if not exists platform text not null default '',
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.app_feedback'::regclass
      and conname = 'app_feedback_user_id_fkey'
  ) then
    alter table public.app_feedback
      add constraint app_feedback_user_id_fkey
      foreign key (user_id) references public.profiles(id) on delete cascade;
  end if;
end $$;

create index if not exists rides_profile_status_created_idx
  on public.rides (profile_id, status, created_at desc)
  where profile_id is not null;

create index if not exists rides_radar_public_active_idx
  on public.rides (ride_visibility, status, created_at desc)
  where ride_visibility = 'public' and status in ('scheduled', 'live', 'active');

create index if not exists ride_routes_profile_updated_idx
  on public.ride_routes (profile_id, updated_at desc)
  where profile_id is not null;

create index if not exists app_feedback_rating_created_idx
  on public.app_feedback (rating, created_at desc);

create index if not exists app_feedback_user_created_idx
  on public.app_feedback (user_id, created_at desc);

create index if not exists app_feedback_auth_user_created_idx
  on public.app_feedback (auth_user_id, created_at desc)
  where auth_user_id is not null;

alter table public.profiles enable row level security;
alter table public.rides enable row level security;
alter table public.ride_routes enable row level security;
alter table public.app_feedback enable row level security;

drop policy if exists profiles_authenticated_all on public.profiles;
create policy profiles_authenticated_all on public.profiles
  for all to authenticated using (true) with check (true);

drop policy if exists rides_authenticated_all on public.rides;
create policy rides_authenticated_all on public.rides
  for all to authenticated using (true) with check (true);

drop policy if exists ride_routes_authenticated_all on public.ride_routes;
create policy ride_routes_authenticated_all on public.ride_routes
  for all to authenticated using (true) with check (true);

drop policy if exists app_feedback_insert_own on public.app_feedback;
drop policy if exists app_feedback_select_own on public.app_feedback;

create policy app_feedback_insert_own
  on public.app_feedback
  for insert
  to authenticated
  with check (
    auth_user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = app_feedback.user_id
        and p.auth_user_id = auth.uid()
    )
  );

create policy app_feedback_select_own
  on public.app_feedback
  for select
  to authenticated
  using (
    auth_user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = app_feedback.user_id
        and p.auth_user_id = auth.uid()
    )
  );

alter table if exists public.rides replica identity full;
alter table if exists public.ride_routes replica identity full;
alter table if exists public.app_feedback replica identity full;
