create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  auth_user_id uuid unique,
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
  add column if not exists auth_user_id uuid,
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

create unique index if not exists profiles_auth_user_id_unique_idx
  on public.profiles (auth_user_id)
  where auth_user_id is not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_auth_user_id_key'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_auth_user_id_key unique (auth_user_id);
  end if;
end $$;

create unique index if not exists profiles_phone_unique_idx
  on public.profiles (phone)
  where phone is not null and phone <> '';

alter table public.profiles enable row level security;

do $$
declare
  policy_record record;
begin
  for policy_record in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
  loop
    execute format(
      'drop policy if exists %I on public.profiles',
      policy_record.policyname
    );
  end loop;
end $$;

create policy profiles_owner_select on public.profiles
  for select
  using (auth.uid() = auth_user_id);

create policy profiles_owner_insert on public.profiles
  for insert
  with check (auth.uid() = auth_user_id);

create policy profiles_owner_update on public.profiles
  for update
  using (auth.uid() = auth_user_id)
  with check (auth.uid() = auth_user_id);
