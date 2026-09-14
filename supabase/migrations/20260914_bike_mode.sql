-- JourneySync Bike Mode profile state.
-- Run this file once in the Supabase SQL editor before relying on cross-device
-- Bike Mode visibility. The app continues to work locally until it is applied.

alter table public.profiles
  add column if not exists bike_mode_enabled boolean not null default false,
  add column if not exists bike_mode_message text,
  add column if not exists bike_mode_messages jsonb not null default '[]'::jsonb,
  add column if not exists bike_mode_updated_at timestamptz;

alter table public.profiles
  drop constraint if exists profiles_bike_mode_message_length;

alter table public.profiles
  add constraint profiles_bike_mode_message_length
  check (bike_mode_message is null or char_length(bike_mode_message) between 1 and 320);

comment on column public.profiles.bike_mode_enabled is
  'User-controlled availability signal. Never auto-disabled by the server.';
comment on column public.profiles.bike_mode_message is
  'Selected Bike Mode auto-reply and in-app availability message.';
comment on column public.profiles.bike_mode_messages is
  'User-authored reusable Bike Mode messages.';

-- Profiles are already part of the publication on current JourneySync installs.
-- This guarded block also supports older environments without failing.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end $$;
