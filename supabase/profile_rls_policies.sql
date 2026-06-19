-- JourneySync profile RLS policies.
-- Run this after the app authenticates users through Supabase Auth.
--
-- The current checked-in schema stores app profiles in public.users. If your
-- deployed schema uses public.profiles instead, use the second block.

-- Current JourneySync schema: public.users
alter table public.users enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can read own user profile'
  ) then
    create policy "Users can read own user profile"
    on public.users
    for select
    to authenticated
    using (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can insert own user profile'
  ) then
    create policy "Users can insert own user profile"
    on public.users
    for insert
    to authenticated
    with check (auth.uid() = id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'Users can update own user profile'
  ) then
    create policy "Users can update own user profile"
    on public.users
    for update
    to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);
  end if;
end $$;

-- Alternate schema if your deployment uses public.profiles:
-- alter table public.profiles enable row level security;
--
-- create policy "Users can read own profile"
-- on public.profiles
-- for select
-- to authenticated
-- using (auth.uid() = id);
--
-- create policy "Users can insert own profile"
-- on public.profiles
-- for insert
-- to authenticated
-- with check (auth.uid() = id);
--
-- create policy "Users can update own profile"
-- on public.profiles
-- for update
-- to authenticated
-- using (auth.uid() = id)
-- with check (auth.uid() = id);
