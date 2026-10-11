-- JourneySync radar depends on Supabase Realtime events from these tables.
-- Safe to run more than once; duplicate publication entries are ignored.

do $$
begin
  begin
    alter publication supabase_realtime add table public.rides;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.ride_members;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.notifications;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

create index if not exists rides_radar_status_created_idx
  on public.rides (status, created_at desc);

create index if not exists ride_members_radar_ride_idx
  on public.ride_members (ride_id);

alter table if exists public.rides replica identity full;
alter table if exists public.ride_members replica identity full;
alter table if exists public.notifications replica identity full;
