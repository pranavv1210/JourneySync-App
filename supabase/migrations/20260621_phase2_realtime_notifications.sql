alter table if exists public.profiles
  add column if not exists fcm_token text,
  add column if not exists push_platform text,
  add column if not exists push_updated_at timestamptz,
  add column if not exists active_ride_id uuid;

alter table if exists public.ride_members
  add column if not exists presence_status text default 'offline',
  add column if not exists last_seen_at timestamptz,
  add column if not exists app_state text;

alter table if exists public.live_locations
  add column if not exists app_state text default 'tracking',
  add column if not exists accuracy double precision,
  add column if not exists queued_at timestamptz;

alter table if exists public.notifications
  add column if not exists profile_id uuid,
  add column if not exists ride_id uuid,
  add column if not exists title text,
  add column if not exists body text,
  add column if not exists category text default 'system',
  add column if not exists payload jsonb default '{}'::jsonb,
  add column if not exists read boolean default false,
  add column if not exists created_at timestamptz default now();

create index if not exists idx_rides_status_created_at
  on public.rides (status, created_at desc);

create index if not exists idx_ride_members_ride_presence
  on public.ride_members (ride_id, presence_status, last_seen_at desc);

create index if not exists idx_live_locations_ride_updated
  on public.live_locations (ride_id, updated_at desc);

create index if not exists idx_notifications_profile_created
  on public.notifications (profile_id, created_at desc);

create index if not exists idx_notifications_profile_unread
  on public.notifications (profile_id, read)
  where read = false;
