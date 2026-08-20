create extension if not exists pgcrypto;

create table if not exists public.ride_members (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member',
  status text not null default 'approved',
  presence_status text default 'offline',
  last_seen_at timestamptz,
  app_state text,
  created_at timestamptz not null default now()
);

alter table if exists public.ride_members
  add column if not exists member_id uuid references public.profiles(id) on delete cascade,
  add column if not exists role text not null default 'member',
  add column if not exists status text not null default 'approved',
  add column if not exists presence_status text default 'offline',
  add column if not exists last_seen_at timestamptz,
  add column if not exists app_state text,
  add column if not exists created_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'user_id'
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
select r.id, r.host_id, 'host', 'approved'
from public.rides r
where r.host_id is not null
  and exists (select 1 from public.profiles p where p.id = r.host_id)
on conflict (ride_id, member_id) do update
set role = 'host',
    status = 'approved';

create table if not exists public.live_locations (
  id uuid primary key default gen_random_uuid(),
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
  avatar_url text,
  is_leader boolean not null default false,
  app_state text default 'tracking',
  accuracy double precision,
  queued_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table if exists public.live_locations
  add column if not exists profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists speed double precision,
  add column if not exists speed_mps double precision,
  add column if not exists heading double precision,
  add column if not exists battery text,
  add column if not exists signal text,
  add column if not exists user_name text not null default 'Rider',
  add column if not exists bike_name text not null default 'No bike added',
  add column if not exists avatar_url text,
  add column if not exists is_leader boolean not null default false,
  add column if not exists app_state text default 'tracking',
  add column if not exists accuracy double precision,
  add column if not exists queued_at timestamptz,
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'live_locations'
      and column_name = 'user_id'
  ) then
    update public.live_locations
    set profile_id = user_id
    where profile_id is null and user_id is not null;
  end if;
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
  add column if not exists profile_id uuid references public.profiles(id) on delete set null,
  add column if not exists user_name text not null default 'Rider',
  add column if not exists type text not null default 'SOS',
  add column if not exists message text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists created_at timestamptz not null default now();

create index if not exists ride_members_member_status_idx
  on public.ride_members (member_id, status, created_at desc);

create index if not exists ride_members_radar_ride_idx
  on public.ride_members (ride_id);

create index if not exists live_locations_ride_updated_idx
  on public.live_locations (ride_id, updated_at desc);

create index if not exists live_locations_profile_updated_idx
  on public.live_locations (profile_id, updated_at desc);

create index if not exists ride_alerts_ride_created_idx
  on public.ride_alerts (ride_id, created_at desc);

alter table public.ride_members enable row level security;
alter table public.live_locations enable row level security;
alter table public.ride_alerts enable row level security;

drop policy if exists ride_members_authenticated_all on public.ride_members;
create policy ride_members_authenticated_all on public.ride_members
  for all to authenticated using (true) with check (true);

drop policy if exists live_locations_authenticated_all on public.live_locations;
create policy live_locations_authenticated_all on public.live_locations
  for all to authenticated using (true) with check (true);

drop policy if exists ride_alerts_authenticated_all on public.ride_alerts;
create policy ride_alerts_authenticated_all on public.ride_alerts
  for all to authenticated using (true) with check (true);

do $$
begin
  begin
    alter publication supabase_realtime add table public.ride_members;
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
end $$;

alter table if exists public.ride_members replica identity full;
alter table if exists public.live_locations replica identity full;
alter table if exists public.ride_alerts replica identity full;
