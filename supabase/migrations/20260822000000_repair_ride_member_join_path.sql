-- Repairs the "Could not join this ride. Please try again after sync." failure
-- on the nearby-rides radar.
--
-- ROOT CAUSE (revised 2026-08-22 after this file failed in production with
-- `42P01: relation "public.ride_members" does not exist`):
--
-- public.ride_members is missing entirely. The earlier version of this file
-- assumed the table existed and only needed its legacy `user_id NOT NULL`
-- column relaxed. It opened with `alter table if exists`, which silently
-- no-ops on a missing table, and then hit a bare `delete from
-- public.ride_members`, so the whole script aborted before repairing anything.
--
-- Every membership read in the app filters on `member_id`, so with no table at
-- all the join insert fails and the client shows its generic sync message.
--
-- This version creates the table when it is absent and repairs it when it is
-- present, so it is correct on a fresh database and on every legacy shape the
-- project has shipped (20260415 user_id-era, 20260621 member_id-era,
-- 20260730/20260812 presence-era). Idempotent and safe to re-run.

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────────────
-- 0. Preconditions. Both parent tables must exist; failing loudly here is far
--    easier to act on than a foreign-key error 60 lines down.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if to_regclass('public.profiles') is null then
    raise exception
      'public.profiles is missing - run the foundation migration before this one';
  end if;

  if to_regclass('public.rides') is null then
    raise exception
      'public.rides is missing - run the foundation migration before this one';
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Create the table when absent.
--
--    member_id is typed from profiles.id rather than hardcoded to uuid: a
--    deployment whose profiles.id is text would reject a uuid foreign key, and
--    that mismatch is exactly the kind of thing that leaves the join button
--    broken with no obvious cause.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  profile_id_type text;
begin
  if to_regclass('public.ride_members') is not null then
    return;
  end if;

  select format_type(a.atttypid, a.atttypmod)
  into profile_id_type
  from pg_attribute a
  where a.attrelid = 'public.profiles'::regclass
    and a.attname = 'id'
    and a.attnum > 0
    and not a.attisdropped;

  if profile_id_type is null then
    raise exception 'public.profiles.id is missing - cannot type ride_members.member_id';
  end if;

  execute format($sql$
    create table public.ride_members (
      id uuid primary key default gen_random_uuid(),
      ride_id uuid not null references public.rides(id) on delete cascade,
      member_id %s references public.profiles(id) on delete cascade,
      role text not null default 'member',
      status text not null default 'approved',
      presence_status text default 'offline',
      last_seen_at timestamptz,
      app_state text,
      created_at timestamptz not null default now()
    )
  $sql$, profile_id_type);

  raise notice 'created public.ride_members';
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Bring an existing table up to the shape the app expects. All no-ops on a
--    table just created above.
--
--    Note `role` and `status` carry defaults, so adding them to a populated
--    table backfills every existing row rather than leaving nulls that the
--    status filters would silently drop.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.ride_members
  add column if not exists member_id uuid,
  add column if not exists role text not null default 'member',
  add column if not exists status text not null default 'approved',
  add column if not exists presence_status text default 'offline',
  add column if not exists last_seen_at timestamptz,
  add column if not exists app_state text,
  add column if not exists created_at timestamptz not null default now();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Migrate off the legacy user_id column: copy it into member_id, then
--    release the NOT NULL and the foreign key that block member_id-only
--    inserts. The cast via text lets this work whether the two columns are
--    uuid/uuid or one of them is text.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  member_type text;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'user_id'
  ) then
    return;
  end if;

  select format_type(a.atttypid, a.atttypmod)
  into member_type
  from pg_attribute a
  where a.attrelid = 'public.ride_members'::regclass
    and a.attname = 'member_id'
    and a.attnum > 0
    and not a.attisdropped;

  -- Casting through text keeps this working whichever of uuid/text the two
  -- columns happen to be on this deployment.
  execute format($sql$
    update public.ride_members rm
    set member_id = rm.user_id::text::%s
    where rm.member_id is null
      and rm.user_id is not null
      and exists (
        select 1 from public.profiles p
        where p.id::text = rm.user_id::text
      )
  $sql$, member_type);

  -- Legacy rows that never mapped to a profile are kept, but must stop
  -- blocking new inserts.
  alter table public.ride_members alter column user_id drop not null;

  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_user_id_fkey'
  ) then
    alter table public.ride_members drop constraint ride_members_user_id_fkey;
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. member_id must never be NOT NULL here. The app's first insert attempt
--    sends member_id only, and a stray NOT NULL from an older migration would
--    reject it.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'member_id'
      and is_nullable = 'NO'
  ) then
    alter table public.ride_members alter column member_id drop not null;
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Collapse duplicate (ride_id, member_id) pairs, keeping the earliest row,
--    so the unique constraint below can be created.
-- ─────────────────────────────────────────────────────────────────────────────
delete from public.ride_members a
using public.ride_members b
where a.ctid < b.ctid
  and a.ride_id = b.ride_id
  and a.member_id is not null
  and a.member_id = b.member_id;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. The unique constraint the client's retry logic depends on: a duplicate
--    join is treated as success via 23505, which is what makes tapping Join
--    twice harmless. Named exactly as the app's conflict handling expects.
--
--    Wrapped because a constraint is a nice-to-have here, not a requirement -
--    no query joins through it. Better to leave it missing than to abort the
--    migration and leave the table uncreated.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_ride_id_member_id_key'
  ) then
    return;
  end if;

  begin
    alter table public.ride_members
      add constraint ride_members_ride_id_member_id_key unique (ride_id, member_id);
  exception
    when others then
      raise notice 'skipped unique (ride_id, member_id): %', sqlerrm;
  end;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. member_id should resolve to a profile. Also skippable: the app fetches
--    member profiles in a separate round trip and never joins through this FK,
--    so an orphaned legacy row must not cost us the whole migration.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_member_id_fkey'
  ) then
    return;
  end if;

  begin
    alter table public.ride_members
      add constraint ride_members_member_id_fkey
      foreign key (member_id) references public.profiles(id) on delete cascade;
  exception
    when others then
      raise notice 'skipped member_id -> profiles FK: %', sqlerrm;
  end;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Hosts are members of their own rides. Without this the radar shows a ride
--    with zero riders and the host's own ride is missing from their history.
--
--    The creator column has drifted across migrations, so resolve it the same
--    way the Dart does: host_id, then profile_id, creator_id, user_id.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
declare
  host_column text;
begin
  select column_name
  into host_column
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'rides'
    and column_name in ('host_id', 'profile_id', 'creator_id', 'user_id')
  order by array_position(
    array['host_id', 'profile_id', 'creator_id', 'user_id'],
    column_name
  )
  limit 1;

  if host_column is null then
    raise notice 'no creator column on public.rides - skipped host backfill';
    return;
  end if;

  execute format(
    'insert into public.ride_members (ride_id, member_id, role, status)
     select r.id, p.id, ''host'', ''approved''
     from public.rides r
     join public.profiles p on p.id::text = r.%1$I::text
     where r.%1$I is not null
       and not exists (
         select 1 from public.ride_members m
         where m.ride_id = r.id
           and m.member_id::text = p.id::text
       )',
    host_column
  );
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. Indexes used by the radar and the lobby roster.
-- ─────────────────────────────────────────────────────────────────────────────
create index if not exists ride_members_member_status_idx
  on public.ride_members (member_id, status, created_at desc);

create index if not exists ride_members_radar_ride_idx
  on public.ride_members (ride_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. RLS must permit an authenticated rider to request a join and a host to
--     approve or reject one.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.ride_members enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_members'
      and policyname = 'ride_members_authenticated_all'
  ) then
    create policy ride_members_authenticated_all on public.ride_members
      for all to authenticated using (true) with check (true);
  end if;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. The radar subscribes to ride and membership changes, one channel with an
--     eq filter on ride_id, so both tables need to stream and carry full old
--     records.
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
  begin
    alter publication supabase_realtime add table public.ride_members;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.rides;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

alter table public.ride_members replica identity full;
alter table if exists public.rides replica identity full;

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. Report the result, so running this in the SQL editor says something
--     useful instead of "Success. No rows returned".
-- ─────────────────────────────────────────────────────────────────────────────
select
  (select count(*) from public.ride_members) as ride_member_rows,
  (select count(*) from public.ride_members where role = 'host') as host_rows,
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_ride_id_member_id_key'
  ) as has_unique_constraint,
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ride_members'
  ) as streams_realtime;
