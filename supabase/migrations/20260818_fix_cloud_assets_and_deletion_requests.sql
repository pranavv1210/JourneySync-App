-- Repairs cloud media/contact writes and adds owner-approved account deletion.

alter table if exists public.profiles
  add column if not exists emergency_contacts jsonb not null default '[]'::jsonb,
  add column if not exists garage_bikes jsonb not null default '[]'::jsonb,
  add column if not exists active_bike_id text,
  add column if not exists auth_user_id uuid;

drop policy if exists profiles_owner_update_cloud_assets on public.profiles;
create policy profiles_owner_update_cloud_assets
  on public.profiles
  for update
  to authenticated
  using (
    auth_user_id = auth.uid()
    or id::text = auth.uid()::text
  )
  with check (
    auth_user_id = auth.uid()
    or id::text = auth.uid()::text
  );

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists avatars_public_select on storage.objects;
drop policy if exists avatars_select_own on storage.objects;
drop policy if exists avatars_insert_own on storage.objects;
drop policy if exists avatars_update_own on storage.objects;
drop policy if exists avatars_delete_own on storage.objects;

create policy avatars_public_select
  on storage.objects
  for select
  to public
  using (bucket_id = 'avatars');

create policy avatars_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = 'profiles'
    and split_part(name, '/', 2) = auth.uid()::text
  );

create policy avatars_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = 'profiles'
    and split_part(name, '/', 2) = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = 'profiles'
    and split_part(name, '/', 2) = auth.uid()::text
  );

create policy avatars_delete_own
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 1) = 'profiles'
    and split_part(name, '/', 2) = auth.uid()::text
  );

do $$
declare
  profile_id_type text;
begin
  select format_type(a.atttypid, a.atttypmod)
    into profile_id_type
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'profiles'
    and a.attname = 'id'
    and not a.attisdropped;

  if profile_id_type is null then
    raise exception 'public.profiles.id must exist before creating account_deletion_requests';
  end if;

  execute format($sql$
    create table if not exists public.account_deletion_requests (
      id uuid primary key default gen_random_uuid(),
      user_id %s not null,
      auth_user_id uuid,
      email text not null default '',
      rider_name text not null default 'Rider',
      status text not null default 'pending'
        check (status in ('pending', 'approved', 'rejected')),
      requested_at timestamptz not null default now(),
      reviewed_at timestamptz,
      reviewed_by uuid
    )
  $sql$, profile_id_type);
end $$;

alter table public.account_deletion_requests
  add column if not exists auth_user_id uuid,
  add column if not exists email text not null default '',
  add column if not exists rider_name text not null default 'Rider',
  add column if not exists status text not null default 'pending',
  add column if not exists requested_at timestamptz not null default now(),
  add column if not exists reviewed_at timestamptz,
  add column if not exists reviewed_by uuid;

create unique index if not exists account_deletion_requests_user_unique
  on public.account_deletion_requests (user_id);

create unique index if not exists account_deletion_requests_auth_user_unique
  on public.account_deletion_requests (auth_user_id)
  where auth_user_id is not null;

alter table public.account_deletion_requests enable row level security;

drop policy if exists account_delete_request_insert_own on public.account_deletion_requests;
drop policy if exists account_delete_request_select_own on public.account_deletion_requests;
drop policy if exists account_delete_request_admin_select on public.account_deletion_requests;
drop policy if exists account_delete_request_admin_update on public.account_deletion_requests;

create policy account_delete_request_insert_own
  on public.account_deletion_requests
  for insert
  to authenticated
  with check (
    auth_user_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = account_deletion_requests.user_id
        and (p.auth_user_id = auth.uid() or p.id::text = auth.uid()::text)
    )
  );

create policy account_delete_request_select_own
  on public.account_deletion_requests
  for select
  to authenticated
  using (
    auth_user_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.id = account_deletion_requests.user_id
        and (p.auth_user_id = auth.uid() or p.id::text = auth.uid()::text)
    )
  );

create policy account_delete_request_admin_select
  on public.account_deletion_requests
  for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com');

create policy account_delete_request_admin_update
  on public.account_deletion_requests
  for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com');

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
