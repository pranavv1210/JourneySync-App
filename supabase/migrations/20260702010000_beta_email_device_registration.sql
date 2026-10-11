create extension if not exists pgcrypto;

create table if not exists public.beta_applications (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  device_id text,
  status text not null default 'pending',
  created_at timestamptz default now()
);

alter table public.beta_applications
add column if not exists email text;

alter table public.beta_applications
add column if not exists device_id text;

alter table public.beta_applications
add column if not exists status text not null default 'pending';

alter table public.beta_applications
add column if not exists created_at timestamptz default now();

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'beta_applications' and column_name = 'name'
  ) then
    alter table public.beta_applications alter column name drop not null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'beta_applications' and column_name = 'city'
  ) then
    alter table public.beta_applications alter column city drop not null;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'beta_applications' and column_name = 'vehicle'
  ) then
    alter table public.beta_applications alter column vehicle drop not null;
  end if;
end $$;

update public.beta_applications
set device_id = 'legacy-' || id::text
where device_id is null;

alter table public.beta_applications
alter column email set not null;

alter table public.beta_applications
alter column device_id set not null;

create unique index if not exists beta_applications_email_unique
on public.beta_applications (lower(email));

create unique index if not exists beta_applications_device_id_unique
on public.beta_applications (device_id);

create index if not exists beta_applications_created_at_idx
on public.beta_applications (created_at desc);

alter table public.beta_applications enable row level security;

drop policy if exists "Anonymous users can create beta applications" on public.beta_applications;
create policy "Anonymous users can create beta applications"
on public.beta_applications
for insert
to anon
with check (true);

drop policy if exists "Authenticated admins can manage beta applications" on public.beta_applications;
create policy "Authenticated admins can manage beta applications"
on public.beta_applications
for all
to authenticated
using (coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false))
with check (coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false));
