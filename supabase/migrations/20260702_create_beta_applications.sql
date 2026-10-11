create extension if not exists pgcrypto;

create table if not exists public.beta_applications (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  city text not null,
  vehicle text not null,
  platform text not null default 'Android',
  status text not null default 'pending',
  created_at timestamptz default now()
);

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

create index if not exists beta_applications_created_at_idx
on public.beta_applications (created_at desc);
