-- Owner dashboard access and cloud persistence helpers.

alter table if exists public.profiles
  add column if not exists emergency_contacts jsonb not null default '[]'::jsonb,
  add column if not exists garage_bikes jsonb not null default '[]'::jsonb,
  add column if not exists active_bike_id text;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists avatars_select_own on storage.objects;
drop policy if exists avatars_insert_own on storage.objects;
drop policy if exists avatars_update_own on storage.objects;

create policy avatars_select_own
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 2) = auth.uid()::text
  );

create policy avatars_insert_own
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and split_part(name, '/', 2) = auth.uid()::text
  );

create policy avatars_update_own
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and split_part(name, '/', 2) = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and split_part(name, '/', 2) = auth.uid()::text
  );

drop policy if exists profiles_admin_select_all on public.profiles;
drop policy if exists rides_admin_select_all on public.rides;
drop policy if exists app_feedback_admin_select_all on public.app_feedback;

create policy profiles_admin_select_all
  on public.profiles
  for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com');

create policy rides_admin_select_all
  on public.rides
  for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com');

create policy app_feedback_admin_select_all
  on public.app_feedback
  for select
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'journeysync.app@gmail.com');
