-- Guarantees the SOS button can actually reach the other riders.
--
-- WHY THIS FILE EXISTS
--
-- Everything public.ride_alerts needs was already written, but it lives in
-- 20260820_repair_ride_coordination_runtime.sql - a long script that also
-- rebuilds ride_members, live_locations and rides. If that file was never run,
-- or aborted partway through on a legacy column type, the SOS insert fails and
-- the rider sees "Could not send SOS. Please try again." with no way to tell
-- whether the problem is the network, the schema, or the policy.
--
-- The client writes exactly eight columns:
--
--   ride_id, profile_id, user_name, type, message, latitude, longitude,
--   created_at
--
-- ...and reads the alert back over realtime. So this file asserts those eight
-- columns, a permissive RLS policy, publication membership, and REPLICA
-- IDENTITY FULL - nothing else. It is deliberately narrow so it can be run on
-- its own, in seconds, without touching the ride tables.
--
-- Idempotent and safe to re-run.
--
-- NOTE ON `type`: the column default is the legacy uppercase 'SOS', while the
-- app now writes lowercase 'sos' / 'safe'. That mismatch is harmless and is NOT
-- "fixed" here on purpose - the client classifies with
-- `type.toLowerCase() != 'safe'`, so every historical spelling of an emergency
-- row still reads as an emergency. Rewriting old rows would risk turning a
-- real recorded alert into a stand-down.

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Preconditions.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception
      'public.profiles does not exist. Run the foundation migrations first.';
  end if;
  if to_regclass('public.rides') is null then
    raise exception
      'public.rides does not exist. Run the foundation migrations first.';
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. The table, and every column the client writes.
--
--    profile_id is typed from the live profiles.id rather than hardcoded to
--    uuid: this project has shipped both uuid and text profile ids, and a
--    hardcoded type is what made an earlier repair abort here.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  profile_id_type text;
  alert_profile_id_type text;
  existing_rows bigint;
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
    raise exception 'Could not determine the type of public.profiles.id.';
  end if;

  if to_regclass('public.ride_alerts') is null then
    execute format($sql$
      create table public.ride_alerts (
        id uuid primary key default gen_random_uuid(),
        ride_id uuid not null references public.rides(id) on delete cascade,
        profile_id %s references public.profiles(id) on delete set null,
        user_name text not null default 'Rider',
        type text not null default 'SOS',
        message text,
        latitude double precision,
        longitude double precision,
        created_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
    raise notice 'Created public.ride_alerts.';
  else
    execute 'alter table public.ride_alerts '
            'add column if not exists id uuid default gen_random_uuid()';
    execute 'alter table public.ride_alerts add column if not exists '
            'ride_id uuid references public.rides(id) on delete cascade';

    select format_type(a.atttypid, a.atttypmod)
      into alert_profile_id_type
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'ride_alerts'
      and a.attname = 'profile_id'
      and not a.attisdropped;

    if alert_profile_id_type is null then
      execute format(
        'alter table public.ride_alerts add column profile_id %s',
        profile_id_type);
    elsif alert_profile_id_type is distinct from profile_id_type then
      execute 'select count(*) from public.ride_alerts' into existing_rows;
      if existing_rows > 0 then
        -- Refusing rather than silently nulling recorded emergencies.
        raise exception
          'public.ride_alerts.profile_id is %, but public.profiles.id is %. '
          'There are % existing rows - migrate or clear them before rerunning.',
          alert_profile_id_type, profile_id_type, existing_rows;
      end if;
      execute 'alter table public.ride_alerts '
              'drop constraint if exists ride_alerts_profile_id_fkey';
      execute format('alter table public.ride_alerts '
                     'alter column profile_id type %s using null',
                     profile_id_type);
    end if;
  end if;

  -- The remaining six are plain adds, so they run for both branches above.
  execute 'alter table public.ride_alerts add column if not exists '
          'user_name text not null default ''Rider''';
  execute 'alter table public.ride_alerts add column if not exists '
          'type text not null default ''SOS''';
  execute 'alter table public.ride_alerts add column if not exists message text';
  execute 'alter table public.ride_alerts add column if not exists '
          'latitude double precision';
  execute 'alter table public.ride_alerts add column if not exists '
          'longitude double precision';
  execute 'alter table public.ride_alerts add column if not exists '
          'created_at timestamptz not null default now()';

  -- A primary key is required for realtime to identify rows.
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.ride_alerts'::regclass and contype = 'p'
  ) then
    execute 'update public.ride_alerts set id = gen_random_uuid() '
            'where id is null';
    execute 'alter table public.ride_alerts add primary key (id)';
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Index for the "recent alerts on this ride" read.
-- ─────────────────────────────────────────────────────────────────────────────
create index if not exists idx_ride_alerts_ride_created
  on public.ride_alerts (ride_id, created_at desc);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RLS. An emergency must never be blocked by a policy, so any authenticated
--    rider may insert and read. This matches ride_members and live_locations.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.ride_alerts enable row level security;

drop policy if exists ride_alerts_all on public.ride_alerts;
drop policy if exists ride_alerts_authenticated_all on public.ride_alerts;
create policy ride_alerts_authenticated_all on public.ride_alerts
  for all to authenticated using (true) with check (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Realtime. Without publication membership the insert succeeds and no other
--    phone ever hears about it, which is the worst possible failure mode here.
--    REPLICA IDENTITY FULL is what makes the payload carry the whole row.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  begin
    alter publication supabase_realtime add table public.ride_alerts;
  exception
    when duplicate_object then null;
    when undefined_object then
      raise notice
        'Publication supabase_realtime not found - realtime may be disabled '
        'for this project.';
  end;
end $$;

alter table if exists public.ride_alerts replica identity full;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Report, so running this in the SQL editor says something useful. Every
--    column below must be true for the SOS button to work end to end.
-- ─────────────────────────────────────────────────────────────────────────────
select
  (select count(*) from public.ride_alerts) as existing_alert_rows,
  (
    select count(*) = 8
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_alerts'
      and column_name in (
        'ride_id', 'profile_id', 'user_name', 'type',
        'message', 'latitude', 'longitude', 'created_at'
      )
  ) as has_all_written_columns,
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_alerts'
      and policyname = 'ride_alerts_authenticated_all'
  ) as has_insert_policy,
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ride_alerts'
  ) as streams_realtime,
  (
    select relreplident = 'f'
    from pg_class
    where oid = 'public.ride_alerts'::regclass
  ) as full_row_payloads;
