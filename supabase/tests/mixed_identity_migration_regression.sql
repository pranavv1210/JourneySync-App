\set ON_ERROR_STOP on

-- Production can have ride_routes keyed only by ride_id. The historical
-- release-hardening migration must skip its optional host index in that shape.
drop table if exists public.ride_routes cascade;
create table public.ride_routes (
  ride_id uuid primary key,
  updated_at timestamptz not null default now()
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ride_routes' and column_name = 'host_id'
  ) and exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'ride_routes' and column_name = 'updated_at'
  ) then
    execute 'create index if not exists ride_routes_host_updated_idx
      on public.ride_routes (host_id, updated_at desc)
      where host_id is not null';
  end if;
end $$;

do $$
begin
  if to_regclass('public.ride_routes_host_updated_idx') is not null then
    raise exception 'Optional ride route host index should not exist without host_id';
  end if;
end $$;

drop table public.ride_routes;

-- Historical JourneySync schemas used both text and uuid identity columns.
-- Bootstrap migrations must normalize source values to the existing host_id
-- type before coalescing them.
create or replace function public.test_backfill_ride_host()
returns void
language plpgsql
as $$
declare
  source_expressions text;
  source_column text;
  host_id_type text;
begin
  if to_regclass('public.users') is not null then
    for source_column in
      select candidate.column_name
      from unnest(array['host_id', 'creator_id', 'user_id', 'leader_id', 'ride_leader_id'])
        as candidate(column_name)
      where exists (
        select 1 from information_schema.columns
        where table_schema = 'public'
          and table_name = 'rides'
          and column_name = candidate.column_name
      )
    loop
      execute format(
        'insert into public.users (id)
         select distinct nullif(%1$I::text, '''')::uuid from public.rides
         where nullif(%1$I::text, '''') ~* ''^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$''
         on conflict (id) do nothing',
        source_column
      );
    end loop;
  end if;

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

  execute format(
    'update public.rides set host_id = coalesce(%s) where host_id is null',
    source_expressions
  );
end $$;

create table public.users (id uuid primary key);
create table public.rides (
  id uuid primary key,
  host_id uuid references public.users(id),
  user_id text
);
insert into public.rides values (
  '00000000-0000-0000-0000-000000000001',
  null,
  '10000000-0000-0000-0000-000000000001'
);
select public.test_backfill_ride_host();
do $$ begin
  if (select host_id from public.rides) <> '10000000-0000-0000-0000-000000000001'::uuid then
    raise exception 'text source was not safely converted to uuid host_id';
  end if;
  if not exists (
    select 1 from public.users
    where id = '10000000-0000-0000-0000-000000000001'::uuid
  ) then
    raise exception 'missing legacy user was not preserved before host backfill';
  end if;
end $$;

drop table public.rides;
drop table public.users;
create table public.rides (
  id uuid primary key,
  host_id text,
  creator_id uuid
);
insert into public.rides values (
  '00000000-0000-0000-0000-000000000002',
  null,
  '10000000-0000-0000-0000-000000000002'
);
select public.test_backfill_ride_host();
do $$ begin
  if (select host_id from public.rides) <> '10000000-0000-0000-0000-000000000002' then
    raise exception 'uuid source was not safely converted to text host_id';
  end if;
end $$;

drop table public.rides;
drop function public.test_backfill_ride_host();

-- Replaying the legacy bootstrap over a canonical membership table must not
-- require or add the obsolete user_id column.
create table public.ride_members (
  id uuid primary key,
  ride_id uuid not null,
  member_id uuid not null
);
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'user_id'
  ) then
    raise exception 'canonical membership fixture unexpectedly has user_id';
  end if;
end $$;
drop table public.ride_members;

-- Realtime publication registration must be safe when a restored snapshot
-- already contains the table.
create table public.live_locations (id uuid primary key);
create publication supabase_realtime;
alter publication supabase_realtime add table public.live_locations;
do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_locations'
  ) then
    alter publication supabase_realtime add table public.live_locations;
  end if;
end $$;
do $$ begin
  if (
    select count(*) from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'live_locations'
  ) <> 1 then
    raise exception 'live_locations realtime publication is not idempotent';
  end if;
end $$;
drop publication supabase_realtime;
drop table public.live_locations;

-- A production-style numeric profile key cannot be populated directly from a
-- legacy UUID users.id. The auth_user_id mapping is handled by later repair
-- migrations, so the historical copy must safely skip incompatible keys.
create table public.users (
  id uuid primary key,
  phone text,
  name text,
  bike text,
  avatar_url text,
  created_at timestamptz
);
create table public.profiles (
  id bigint generated by default as identity primary key,
  auth_user_id uuid unique,
  phone text,
  name text,
  bike text,
  avatar_url text,
  created_at timestamptz
);
insert into public.users values (
  '10000000-0000-0000-0000-000000000003', null, 'Legacy', 'Bike', null, now()
);
do $$
declare profiles_id_type text;
declare users_id_type text;
begin
  select format_type(a.atttypid,a.atttypmod) into profiles_id_type
  from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='id' and not a.attisdropped;
  select format_type(a.atttypid,a.atttypmod) into users_id_type
  from pg_attribute a where a.attrelid='public.users'::regclass and a.attname='id' and not a.attisdropped;
  if profiles_id_type = users_id_type then
    execute 'insert into public.profiles(id) select id from public.users on conflict(id) do nothing';
  end if;
end $$;
do $$ begin
  if exists (select 1 from public.profiles) then
    raise exception 'incompatible UUID users were copied into bigint profiles';
  end if;
end $$;
create table public.rides (id uuid primary key);
do $$
declare profile_id_type text;
begin
  select format_type(a.atttypid,a.atttypmod) into profile_id_type
  from pg_attribute a where a.attrelid='public.profiles'::regclass and a.attname='id' and not a.attisdropped;
  execute format('create table public.notifications(id uuid primary key, profile_id %s references public.profiles(id), ride_id uuid references public.rides(id))',profile_id_type);
  execute format('create table public.ride_summaries(ride_id uuid primary key references public.rides(id), host_id %s references public.profiles(id))',profile_id_type);
end $$;
do $$ begin
  if (select udt_name from information_schema.columns where table_schema='public' and table_name='notifications' and column_name='profile_id') <> 'int8'
     or (select udt_name from information_schema.columns where table_schema='public' and table_name='ride_summaries' and column_name='host_id') <> 'int8' then
    raise exception 'profile-dependent table keys did not inherit bigint profile identity';
  end if;
end $$;
drop table public.notifications;
drop table public.ride_summaries;
drop table public.rides;
drop table public.profiles;
drop table public.users;

-- A UUID ride host also cannot be materialized as a numeric profile id. The
-- repair migration must leave that mapping to profiles.auth_user_id instead
-- of attempting an invalid cross-type insert.
create table public.profiles (
  id bigint generated by default as identity primary key,
  auth_user_id uuid unique,
  name text,
  bike text
);
create table public.rides (
  id uuid primary key,
  host_id uuid not null
);
insert into public.rides values (
  '00000000-0000-0000-0000-000000000004',
  '10000000-0000-0000-0000-000000000004'
);
do $$
declare
  profiles_id_type text;
  rides_host_type text;
begin
  select format_type(a.atttypid, a.atttypmod) into profiles_id_type
  from pg_attribute a
  where a.attrelid = 'public.profiles'::regclass and a.attname = 'id' and not a.attisdropped;
  select format_type(a.atttypid, a.atttypmod) into rides_host_type
  from pg_attribute a
  where a.attrelid = 'public.rides'::regclass and a.attname = 'host_id' and not a.attisdropped;
  if profiles_id_type = rides_host_type and profiles_id_type = 'uuid' then
    execute 'insert into public.profiles(id, auth_user_id, name, bike)
      select distinct host_id, host_id, ''Rider'', ''No bike added'' from public.rides
      where host_id is not null on conflict(id) do nothing';
  end if;
end $$;
do $$ begin
  if exists (select 1 from public.profiles) then
    raise exception 'incompatible UUID ride host was copied into bigint profiles';
  end if;
end $$;
insert into public.profiles (id, auth_user_id, name, bike) values (
  4004, '10000000-0000-0000-0000-000000000004', 'Mapped host', 'Bike'
);
create table public.ride_members (
  ride_id uuid not null,
  member_id bigint not null references public.profiles(id),
  role text not null,
  status text not null,
  unique (ride_id, member_id)
);
do $$
declare
  profiles_id_type text;
  profiles_auth_type text;
  rides_host_type text;
begin
  select format_type(a.atttypid, a.atttypmod) into profiles_id_type
  from pg_attribute a
  where a.attrelid = 'public.profiles'::regclass and a.attname = 'id' and not a.attisdropped;
  select format_type(a.atttypid, a.atttypmod) into rides_host_type
  from pg_attribute a
  where a.attrelid = 'public.rides'::regclass and a.attname = 'host_id' and not a.attisdropped;
  select format_type(a.atttypid, a.atttypmod) into profiles_auth_type
  from pg_attribute a
  where a.attrelid = 'public.profiles'::regclass and a.attname = 'auth_user_id' and not a.attisdropped;
  if profiles_id_type = rides_host_type then
    execute 'insert into public.ride_members select r.id, r.host_id, ''host'', ''approved''
      from public.rides r join public.profiles p on p.id = r.host_id
      on conflict(ride_id, member_id) do update set role=''host'', status=''approved''';
  elsif profiles_auth_type = rides_host_type then
    execute 'insert into public.ride_members select r.id, p.id, ''host'', ''approved''
      from public.rides r join public.profiles p on p.auth_user_id = r.host_id
      on conflict(ride_id, member_id) do update set role=''host'', status=''approved''';
  end if;
end $$;
do $$ begin
  if not exists (
    select 1 from public.ride_members
    where member_id = 4004 and role = 'host' and status = 'approved'
  ) then
    raise exception 'UUID ride host was not mapped through profiles.auth_user_id';
  end if;
end $$;
drop table public.ride_members;

create table public.live_locations (
  profile_id bigint references public.profiles(id),
  user_id text
);
create table public.ride_alerts (
  profile_id bigint references public.profiles(id),
  user_id text
);
insert into public.live_locations (user_id) values ('10000000-0000-0000-0000-000000000004');
insert into public.ride_alerts (user_id) values ('10000000-0000-0000-0000-000000000004');
update public.live_locations location
set profile_id = profile.id
from public.profiles profile
where location.profile_id is null and location.user_id is not null
  and profile.auth_user_id::text = location.user_id::text;
update public.ride_alerts alert
set profile_id = profile.id
from public.profiles profile
where alert.profile_id is null and alert.user_id is not null
  and profile.auth_user_id::text = alert.user_id::text;
do $$ begin
  if (select profile_id from public.live_locations) <> 4004
     or (select profile_id from public.ride_alerts) <> 4004 then
    raise exception 'legacy location or alert identity was not mapped to bigint profile';
  end if;
end $$;
drop table public.live_locations;
drop table public.ride_alerts;
drop table public.rides;
drop table public.profiles;
