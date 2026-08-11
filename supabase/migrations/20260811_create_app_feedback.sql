-- Simple JourneySync in-app feedback.

create extension if not exists "pgcrypto";

create table if not exists public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  improvement_feedback text,
  app_version text not null default '',
  platform text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists app_feedback_rating_created_idx
  on public.app_feedback (rating, created_at desc);

create index if not exists app_feedback_user_created_idx
  on public.app_feedback (user_id, created_at desc);

alter table public.app_feedback enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'app_feedback'
      and policyname = 'app_feedback_insert_own'
  ) then
    create policy app_feedback_insert_own
      on public.app_feedback
      for insert
      to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'app_feedback'
      and policyname = 'app_feedback_select_own'
  ) then
    create policy app_feedback_select_own
      on public.app_feedback
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;
end $$;
