\set ON_ERROR_STOP on

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
