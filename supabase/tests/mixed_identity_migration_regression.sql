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
