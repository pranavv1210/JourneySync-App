-- JourneySync single-device session enforcement and realtime deletion logout.

create table if not exists public.user_device_sessions (
  profile_id text primary key,
  auth_user_id uuid,
  device_id text not null,
  session_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  deleted_at timestamptz
);

create index if not exists user_device_sessions_auth_user_idx
  on public.user_device_sessions (auth_user_id);

alter table public.user_device_sessions enable row level security;

create or replace function public.profile_auth_matches_text(
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
    from public.profiles p
    where p.id::text = target_profile_id
      and (
        p.id::text = auth.uid()::text
        or coalesce(to_jsonb(p)->>'auth_user_id', '') = auth.uid()::text
      )
  )
$$;

drop policy if exists user_device_sessions_owner_select
  on public.user_device_sessions;

create policy user_device_sessions_owner_select
  on public.user_device_sessions
  for select
  to authenticated
  using (
    auth_user_id = auth.uid()
    or public.profile_auth_matches_text(profile_id)
  );

drop policy if exists user_device_sessions_admin_select
  on public.user_device_sessions;

create policy user_device_sessions_admin_select
  on public.user_device_sessions
  for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com');

create or replace function public.register_device_session(
  p_profile_id text,
  p_device_id text,
  p_session_token text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_profile_id text := trim(coalesce(p_profile_id, ''));
  normalized_device_id text := trim(coalesce(p_device_id, ''));
  normalized_session_token text := trim(coalesce(p_session_token, ''));
  resolved_auth_user_id uuid := auth.uid();
begin
  if auth.uid() is null then
    raise exception 'Sign in before registering this device.';
  end if;

  if normalized_profile_id = ''
     or normalized_device_id = ''
     or normalized_session_token = '' then
    raise exception 'Device session registration is missing required values.';
  end if;

  if not public.profile_auth_matches_text(normalized_profile_id)
     and normalized_profile_id <> auth.uid()::text then
    raise exception 'This device cannot register a session for another rider.';
  end if;

  insert into public.user_device_sessions (
    profile_id,
    auth_user_id,
    device_id,
    session_token,
    created_at,
    updated_at,
    last_seen_at,
    revoked_at,
    deleted_at
  )
  values (
    normalized_profile_id,
    resolved_auth_user_id,
    normalized_device_id,
    normalized_session_token,
    now(),
    now(),
    now(),
    null,
    null
  )
  on conflict (profile_id) do update
    set auth_user_id = excluded.auth_user_id,
        device_id = excluded.device_id,
        session_token = excluded.session_token,
        updated_at = now(),
        last_seen_at = now(),
        revoked_at = null,
        deleted_at = null;
end;
$$;

grant execute on function public.register_device_session(text, text, text)
  to authenticated;

create or replace function public.admin_approve_account_deletion_request(
  p_request_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  request_row record;
  profile_id_text text;
  auth_user_id_value uuid;
  ride_ids uuid[];
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'journeysync.app@gmail.com' then
    raise exception 'Only the JourneySync owner can approve account deletion requests.';
  end if;

  select *
    into request_row
  from public.account_deletion_requests
  where id = p_request_id
    and status = 'pending';

  if not found then
    raise exception 'Pending account deletion request not found.';
  end if;

  profile_id_text := request_row.user_id::text;
  auth_user_id_value := request_row.auth_user_id;

  if auth_user_id_value is null then
    select p.auth_user_id
      into auth_user_id_value
    from public.profiles p
    where p.id::text = profile_id_text
    limit 1;
  end if;

  if to_regclass('public.user_device_sessions') is not null then
    update public.user_device_sessions
      set revoked_at = now(),
          deleted_at = now(),
          updated_at = now()
    where profile_id = profile_id_text
       or (
        auth_user_id_value is not null
        and auth_user_id = auth_user_id_value
      );
  end if;

  select coalesce(array_agg(id), array[]::uuid[])
    into ride_ids
  from public.rides
  where host_id::text = profile_id_text;

  if to_regclass('public.ride_members') is not null then
    delete from public.ride_members where member_id::text = profile_id_text;
    if ride_ids is not null and array_length(ride_ids, 1) is not null then
      delete from public.ride_members where ride_id = any(ride_ids);
    end if;
  end if;

  if to_regclass('public.live_locations') is not null then
    delete from public.live_locations where profile_id::text = profile_id_text;
    if ride_ids is not null and array_length(ride_ids, 1) is not null then
      delete from public.live_locations where ride_id = any(ride_ids);
    end if;
  end if;

  if to_regclass('public.ride_alerts') is not null then
    delete from public.ride_alerts where profile_id::text = profile_id_text;
    if ride_ids is not null and array_length(ride_ids, 1) is not null then
      delete from public.ride_alerts where ride_id = any(ride_ids);
    end if;
  end if;

  if to_regclass('public.notifications') is not null then
    delete from public.notifications where profile_id::text = profile_id_text;
    if ride_ids is not null and array_length(ride_ids, 1) is not null then
      delete from public.notifications where ride_id = any(ride_ids);
    end if;
  end if;

  if to_regclass('public.ride_routes') is not null
     and ride_ids is not null
     and array_length(ride_ids, 1) is not null then
    delete from public.ride_routes where ride_id = any(ride_ids);
  end if;

  if to_regclass('public.ride_summaries') is not null
     and ride_ids is not null
     and array_length(ride_ids, 1) is not null then
    delete from public.ride_summaries where ride_id = any(ride_ids);
  end if;

  if to_regclass('public.app_feedback') is not null then
    delete from public.app_feedback
    where user_id::text = profile_id_text
       or (auth_user_id_value is not null and auth_user_id = auth_user_id_value);
  end if;

  if ride_ids is not null and array_length(ride_ids, 1) is not null then
    delete from public.rides where id = any(ride_ids);
  end if;

  delete from storage.objects
  where bucket_id = 'avatars'
    and (
      name like ('profiles/' || profile_id_text || '/%')
      or (
        auth_user_id_value is not null
        and name like ('profiles/' || auth_user_id_value::text || '/%')
      )
    );

  delete from public.profiles
  where id::text = profile_id_text
     or (auth_user_id_value is not null and auth_user_id = auth_user_id_value);

  delete from auth.users
  where auth_user_id_value is not null
    and id = auth_user_id_value;

  delete from public.account_deletion_requests
  where id = p_request_id;
end;
$$;

grant execute on function public.admin_approve_account_deletion_request(uuid)
  to authenticated;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'user_device_sessions'
    ) then
      alter publication supabase_realtime add table public.user_device_sessions;
    end if;
  end if;
end;
$$;

select
  to_regclass('public.user_device_sessions') is not null
    as has_user_device_sessions,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'register_device_session'
  ) as has_register_device_session,
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'user_device_sessions'
  ) as streams_realtime;
