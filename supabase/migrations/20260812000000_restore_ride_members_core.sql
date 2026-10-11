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
  created_at timestamptz not null default now(),
  unique (ride_id, member_id)
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

alter table if exists public.ride_routes
  add column if not exists host_id uuid references public.profiles(id) on delete set null,
  add column if not exists start_label text not null default '',
  add column if not exists end_label text not null default '',
  add column if not exists stops jsonb not null default '[]'::jsonb,
  add column if not exists destination_lat double precision,
  add column if not exists destination_lng double precision,
  add column if not exists route_points jsonb,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists ride_members_member_status_idx
  on public.ride_members (member_id, status, created_at desc);

create index if not exists ride_members_radar_ride_idx
  on public.ride_members (ride_id);

alter table public.ride_members enable row level security;
alter table public.ride_routes enable row level security;

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

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_routes'
      and policyname = 'ride_routes_authenticated_all'
  ) then
    create policy ride_routes_authenticated_all on public.ride_routes
      for all to authenticated using (true) with check (true);
  end if;
end $$;

do $$
begin
  begin
    alter publication supabase_realtime add table public.ride_members;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

alter table if exists public.ride_members replica identity full;
