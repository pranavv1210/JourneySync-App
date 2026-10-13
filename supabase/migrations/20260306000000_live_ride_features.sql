-- JourneySync live ride production schema updates
-- Run this in Supabase SQL editor (project database).

-- 1) Store per-user live GPS so map markers can show each rider accurately.
alter table if exists public.users
  add column if not exists current_lat double precision,
  add column if not exists current_lng double precision,
  add column if not exists current_speed_mps double precision,
  add column if not exists current_heading double precision,
  add column if not exists location_updated_at timestamptz,
  add column if not exists active_ride_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_active_ride_id_fkey'
  ) then
    alter table public.users
      add constraint users_active_ride_id_fkey
      foreign key (active_ride_id) references public.rides(id) on delete set null;
  end if;
end $$;

create index if not exists idx_users_active_ride_id
  on public.users(active_ride_id);

create index if not exists idx_users_live_location
  on public.users(active_ride_id, location_updated_at);

-- 2) Group chat table used by live ride screen.
create table if not exists public.ride_messages (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  message text not null check (length(trim(message)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists idx_ride_messages_ride_created
  on public.ride_messages(ride_id, created_at);

create index if not exists idx_ride_messages_user
  on public.ride_messages(user_id);

alter table public.ride_messages enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_messages'
      and policyname = 'ride_messages_select_all'
  ) then
    create policy ride_messages_select_all
      on public.ride_messages
      for select
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_messages'
      and policyname = 'ride_messages_insert_all'
  ) then
    create policy ride_messages_insert_all
      on public.ride_messages
      for insert
      with check (true);
  end if;
end $$;

