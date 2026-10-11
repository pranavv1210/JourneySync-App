-- Optional profile persistence for garage restore across reinstall/sign-in.

alter table if exists public.profiles
  add column if not exists garage_bikes jsonb not null default '[]'::jsonb,
  add column if not exists active_bike_id text;

create index if not exists profiles_active_bike_id_idx
  on public.profiles (active_bike_id)
  where active_bike_id is not null;
