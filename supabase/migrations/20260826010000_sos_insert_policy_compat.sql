-- JourneySync SOS insert compatibility for legacy auth/profile id mappings.
--
-- Some production profiles do not map cleanly from auth.uid() to profiles.id,
-- while the app correctly sends profiles.id in ride_alerts.profile_id. This
-- keeps SOS scoped to the ride but allows the insert when the alert profile is
-- actually a host/member of that ride.

create or replace function public.profile_is_ride_participant_text(
  target_ride_id text,
  target_profile_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rides r
    where r.id::text = target_ride_id
      and (
        coalesce(to_jsonb(r)->>'host_id', '') = target_profile_id
        or coalesce(to_jsonb(r)->>'profile_id', '') = target_profile_id
        or coalesce(to_jsonb(r)->>'creator_id', '') = target_profile_id
        or coalesce(to_jsonb(r)->>'user_id', '') = target_profile_id
      )
  )
  or exists (
    select 1
    from public.ride_members rm
    where rm.ride_id::text = target_ride_id
      and coalesce(
        to_jsonb(rm)->>'member_id',
        to_jsonb(rm)->>'user_id',
        ''
      ) = target_profile_id
      and coalesce(to_jsonb(rm)->>'status', 'joined') <> 'removed'
  )
$$;

create or replace function public.profile_is_ride_host_text(
  target_ride_id text,
  target_profile_id text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rides r
    where r.id::text = target_ride_id
      and (
        coalesce(to_jsonb(r)->>'host_id', '') = target_profile_id
        or coalesce(to_jsonb(r)->>'profile_id', '') = target_profile_id
        or coalesce(to_jsonb(r)->>'creator_id', '') = target_profile_id
        or coalesce(to_jsonb(r)->>'user_id', '') = target_profile_id
      )
  )
$$;

drop policy if exists ride_alerts_participant_insert on public.ride_alerts;

create policy ride_alerts_participant_insert on public.ride_alerts
  for insert to authenticated
  with check (
    (
      lower(coalesce(type, 'sos')) in ('sos', 'safe')
      and public.profile_is_ride_participant_text(
        ride_id::text,
        profile_id::text
      )
    )
    or (
      lower(coalesce(type, '')) in ('sos_acknowledged', 'group_sos')
      and public.profile_is_ride_participant_text(
        ride_id::text,
        profile_id::text
      )
      and public.profile_is_ride_host_text(
        ride_id::text,
        coalesce(acknowledged_by, public.current_profile_id_text())
      )
    )
    or (
      lower(coalesce(type, '')) = 'group_acknowledged'
      and public.profile_is_ride_participant_text(
        ride_id::text,
        coalesce(acknowledged_by, '')
      )
    )
  );

select
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_alerts'
      and policyname = 'ride_alerts_participant_insert'
  ) as has_sos_insert_policy;
