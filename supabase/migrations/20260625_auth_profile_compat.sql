create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  name text not null default 'Rider',
  bike text not null default 'No bike added',
  avatar_url text,
  active_ride_id uuid,
  fcm_token text,
  push_platform text,
  push_updated_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.profiles
  add column if not exists phone text,
  add column if not exists name text not null default 'Rider',
  add column if not exists bike text not null default 'No bike added',
  add column if not exists avatar_url text,
  add column if not exists active_ride_id uuid,
  add column if not exists fcm_token text,
  add column if not exists push_platform text,
  add column if not exists push_updated_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists profiles_phone_unique_idx
  on public.profiles (phone)
  where phone is not null and phone <> '';

alter table public.profiles enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_owner_select'
  ) then
    create policy profiles_owner_select on public.profiles
      for select
      using (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_owner_insert'
  ) then
    create policy profiles_owner_insert on public.profiles
      for insert
      with check (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_owner_update'
  ) then
    create policy profiles_owner_update on public.profiles
      for update
      using (auth.uid() = id)
      with check (auth.uid() = id);
  end if;
end $$;
