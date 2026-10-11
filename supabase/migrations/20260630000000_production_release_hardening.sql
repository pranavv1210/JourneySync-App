-- Production release hardening for high-volume ride queries and owner-scoped data.

create index if not exists profiles_active_ride_idx
  on public.profiles (active_ride_id)
  where active_ride_id is not null;

create index if not exists rides_host_status_created_idx
  on public.rides (host_id, status, created_at desc);

create index if not exists ride_members_member_status_idx
  on public.ride_members (member_id, status, created_at desc);

create index if not exists live_locations_profile_updated_idx
  on public.live_locations (profile_id, updated_at desc)
  where profile_id is not null;

create index if not exists ride_routes_host_updated_idx
  on public.ride_routes (host_id, updated_at desc)
  where host_id is not null;

create index if not exists ride_alerts_profile_created_idx
  on public.ride_alerts (profile_id, created_at desc)
  where profile_id is not null;

create index if not exists ride_summaries_host_created_idx
  on public.ride_summaries (host_id, created_at desc)
  where host_id is not null;

create index if not exists ride_summaries_created_idx
  on public.ride_summaries (created_at desc);

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'notifications_owner_select'
  ) then
    create policy notifications_owner_select on public.notifications
      for select to authenticated
      using (profile_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'notifications'
      and policyname = 'notifications_owner_update'
  ) then
    create policy notifications_owner_update on public.notifications
      for update to authenticated
      using (profile_id = auth.uid())
      with check (profile_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_summaries'
      and policyname = 'ride_summaries_authenticated_select'
  ) then
    create policy ride_summaries_authenticated_select on public.ride_summaries
      for select to authenticated
      using (
        host_id = auth.uid()
        or exists (
          select 1
          from public.ride_members rm
          where rm.ride_id = ride_summaries.ride_id
            and rm.member_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'ride_summaries'
      and policyname = 'ride_summaries_host_write'
  ) then
    create policy ride_summaries_host_write on public.ride_summaries
      for all to authenticated
      using (host_id = auth.uid())
      with check (host_id = auth.uid());
  end if;
end $$;
