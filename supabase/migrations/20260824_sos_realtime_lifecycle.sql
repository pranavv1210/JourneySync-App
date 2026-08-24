-- JourneySync SOS realtime lifecycle and scoped RLS.
--
-- Adds the metadata needed for a real emergency flow over public.ride_alerts:
--   sos -> sos_acknowledged -> group_sos -> group_acknowledged -> safe
--
-- Idempotent and safe to re-run after the existing ride_alerts repair
-- migrations.

create extension if not exists pgcrypto;

alter table public.ride_alerts
  add column if not exists avatar_url text,
  add column if not exists acknowledged_by text,
  add column if not exists original_alert_id uuid references public.ride_alerts(id) on delete set null;

create index if not exists ride_alerts_original_alert_idx
  on public.ride_alerts (original_alert_id)
  where original_alert_id is not null;

create index if not exists ride_alerts_acknowledged_by_idx
  on public.ride_alerts (acknowledged_by, created_at desc)
  where acknowledged_by is not null;

create or replace function public.current_profile_id_text()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select p.id::text
      from public.profiles p
      where p.auth_user_id = auth.uid()
         or p.id::text = auth.uid()::text
      limit 1
    ),
    auth.uid()::text
  )
$$;

create or replace function public.is_ride_participant_text(target_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rides r
    where r.id = target_ride_id
      and (
        coalesce(r.host_id::text, '') = public.current_profile_id_text()
        or coalesce(r.profile_id::text, '') = public.current_profile_id_text()
        or coalesce(r.creator_id::text, '') = public.current_profile_id_text()
        or coalesce(r.user_id::text, '') = public.current_profile_id_text()
      )
  )
  or exists (
    select 1
    from public.ride_members rm
    where rm.ride_id = target_ride_id
      and rm.member_id::text = public.current_profile_id_text()
      and coalesce(rm.status, 'joined') <> 'removed'
  )
$$;

create or replace function public.is_ride_host_text(target_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.rides r
    where r.id = target_ride_id
      and (
        coalesce(r.host_id::text, '') = public.current_profile_id_text()
        or coalesce(r.profile_id::text, '') = public.current_profile_id_text()
        or coalesce(r.creator_id::text, '') = public.current_profile_id_text()
        or coalesce(r.user_id::text, '') = public.current_profile_id_text()
      )
  )
$$;

alter table public.ride_alerts enable row level security;

drop policy if exists ride_alerts_all on public.ride_alerts;
drop policy if exists ride_alerts_authenticated_all on public.ride_alerts;
drop policy if exists ride_alerts_participant_select on public.ride_alerts;
drop policy if exists ride_alerts_participant_insert on public.ride_alerts;

create policy ride_alerts_participant_select on public.ride_alerts
  for select to authenticated
  using (public.is_ride_participant_text(ride_id));

create policy ride_alerts_participant_insert on public.ride_alerts
  for insert to authenticated
  with check (
    public.is_ride_participant_text(ride_id)
    and (
      (
        lower(coalesce(type, 'sos')) in ('sos', 'safe')
        and profile_id::text = public.current_profile_id_text()
      )
      or (
        lower(coalesce(type, '')) in ('sos_acknowledged', 'group_sos')
        and public.is_ride_host_text(ride_id)
      )
      or (
        lower(coalesce(type, '')) = 'group_acknowledged'
        and coalesce(acknowledged_by, '') = public.current_profile_id_text()
      )
    )
  );

do $$
begin
  begin
    alter publication supabase_realtime add table public.ride_alerts;
  exception
    when duplicate_object then null;
    when undefined_object then
      raise notice 'Publication supabase_realtime not found; enable realtime for ride_alerts manually.';
  end;
end $$;

alter table if exists public.ride_alerts replica identity full;

select
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_alerts'
      and column_name = 'avatar_url'
  ) as has_avatar_url,
  exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'ride_alerts'
      and policyname = 'ride_alerts_participant_insert'
  ) as has_scoped_insert_policy,
  exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'ride_alerts'
  ) as streams_realtime;
