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

  execute format(
    'update public.rides set host_id = coalesce(%s) where host_id is null',
    source_expressions
  );
end $$;

create table public.rides (
  id uuid primary key,
  host_id uuid,
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
end $$;

drop table public.rides;
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
