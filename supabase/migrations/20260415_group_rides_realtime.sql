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

do $$
declare
  source_expressions text;
  source_column text;
  host_id_type text;
begin
  -- Some legacy rides contain valid auth UUIDs before a matching legacy user
  -- row exists. Preserve ownership and satisfy the host foreign key before
  -- backfilling host_id; foundation_v2 later promotes these rows to profiles.
  for source_column in
    select candidate.column_name
    from unnest(array['host_id', 'creator_id', 'user_id', 'leader_id', 'ride_leader_id'])
      as candidate(column_name)
    where exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'rides'
        and column_name = candidate.column_name
    )
  loop
    execute format(
      'insert into public.users (id)
       select distinct nullif(%1$I::text, '''')::uuid
       from public.rides
       where nullif(%1$I::text, '''') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$''
       on conflict (id) do nothing',
      source_column
    );
  end loop;

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
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (ride_id, user_id)
);

do $$
begin
  -- A current-schema ride_members table uses member_id. Do not introduce or
  -- write the obsolete user_id shape when replaying history over that schema.
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'user_id'
  ) then
    execute $sql$
      insert into public.ride_members (ride_id, user_id)
      select r.id, r.host_id
      from public.rides r
      where r.host_id is not null
        and not exists (
          select 1 from public.ride_members rm
          where rm.ride_id = r.id and rm.user_id = r.host_id
        )
    $sql$;

    if to_regclass('public.participants') is not null
       and exists (
         select 1 from information_schema.columns
         where table_schema = 'public'
           and table_name = 'participants'
           and column_name = 'ride_id'
       )
       and exists (
         select 1 from information_schema.columns
         where table_schema = 'public'
           and table_name = 'participants'
           and column_name = 'user_id'
       ) then
      execute $sql$
        insert into public.ride_members (ride_id, user_id)
        select p.ride_id, p.user_id
        from public.participants p
        where not exists (
          select 1 from public.ride_members rm
          where rm.ride_id = p.ride_id and rm.user_id = p.user_id
        )
      $sql$;
    end if;
  end if;
end $$;

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
