-- Repair app_feedback for databases where profiles.id is not uuid.
-- Safe to run after a failed manual attempt: it creates the table first, fixes
-- empty wrong-typed feedback tables, then recreates RLS policies.

create extension if not exists "pgcrypto";

alter table if exists public.profiles
  add column if not exists auth_user_id uuid;

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
    raise exception 'public.profiles.id must exist before creating app_feedback';
  end if;

  execute format($sql$
    create table if not exists public.app_feedback (
      id uuid primary key default gen_random_uuid(),
      user_id %s not null,
      auth_user_id uuid,
      rating integer not null check (rating between 1 and 5),
      improvement_feedback text,
      app_version text not null default '',
      platform text not null default '',
      created_at timestamptz not null default now()
    )
  $sql$, profile_id_type);
end $$;

do $$
declare
  profile_id_type text;
  feedback_user_id_type text;
  feedback_rows bigint := 0;
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

  select format_type(a.atttypid, a.atttypmod)
    into feedback_user_id_type
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname = 'app_feedback'
    and a.attname = 'user_id'
    and not a.attisdropped;

  execute 'select count(*) from public.app_feedback' into feedback_rows;

  if feedback_user_id_type is distinct from profile_id_type then
    if feedback_rows > 0 then
      raise exception 'public.app_feedback.user_id is %, but public.profiles.id is %. Resolve existing feedback rows before changing the column type.',
        feedback_user_id_type, profile_id_type;
    end if;

    alter table public.app_feedback
      drop constraint if exists app_feedback_user_id_fkey;

    execute format(
      'alter table public.app_feedback alter column user_id type %s using null',
      profile_id_type
    );

    alter table public.app_feedback
      alter column user_id set not null;
  end if;

  alter table public.app_feedback
    add column if not exists auth_user_id uuid,
    add column if not exists improvement_feedback text,
    add column if not exists app_version text not null default '',
    add column if not exists platform text not null default '',
    add column if not exists created_at timestamptz not null default now();

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.app_feedback'::regclass
      and conname = 'app_feedback_user_id_fkey'
  ) then
    execute 'alter table public.app_feedback add constraint app_feedback_user_id_fkey foreign key (user_id) references public.profiles(id) on delete cascade';
  end if;
end $$;

create index if not exists app_feedback_rating_created_idx
  on public.app_feedback (rating, created_at desc);

create index if not exists app_feedback_user_created_idx
  on public.app_feedback (user_id, created_at desc);

create index if not exists app_feedback_auth_user_created_idx
  on public.app_feedback (auth_user_id, created_at desc)
  where auth_user_id is not null;

alter table public.app_feedback enable row level security;

drop policy if exists app_feedback_insert_own on public.app_feedback;
drop policy if exists app_feedback_select_own on public.app_feedback;

create policy app_feedback_insert_own
  on public.app_feedback
  for insert
  to authenticated
  with check (
    auth_user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = app_feedback.user_id
        and p.auth_user_id = auth.uid()
    )
  );

create policy app_feedback_select_own
  on public.app_feedback
  for select
  to authenticated
  using (
    auth_user_id = auth.uid()
    or exists (
      select 1
      from public.profiles p
      where p.id = app_feedback.user_id
        and p.auth_user_id = auth.uid()
    )
  );
