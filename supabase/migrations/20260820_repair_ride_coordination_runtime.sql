create extension if not exists pgcrypto;

do $$
declare
  profile_id_type text;
  member_id_type text;
  live_profile_id_type text;
  alert_profile_id_type text;
  row_count bigint;
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
    raise exception 'public.profiles.id must exist before repairing ride coordination tables';
  end if;

  if to_regclass('public.rides') is null then
    raise exception 'public.rides must exist before repairing ride coordination tables';
  end if;

  execute format('alter table public.rides add column if not exists profile_id %s', profile_id_type);

  if to_regclass('public.ride_members') is null then
    execute format($sql$
      create table public.ride_members (
        id uuid primary key default gen_random_uuid(),
        ride_id uuid not null references public.rides(id) on delete cascade,
        member_id %s not null references public.profiles(id) on delete cascade,
        role text not null default 'member',
        status text not null default 'approved',
        presence_status text default 'offline',
        last_seen_at timestamptz,
        app_state text,
        created_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
  else
    execute 'alter table public.ride_members add column if not exists id uuid default gen_random_uuid()';
    execute 'alter table public.ride_members add column if not exists ride_id uuid references public.rides(id) on delete cascade';

    select format_type(a.atttypid, a.atttypmod)
      into member_id_type
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'ride_members'
      and a.attname = 'member_id'
      and not a.attisdropped;

    if member_id_type is null then
      execute format('alter table public.ride_members add column member_id %s', profile_id_type);
    elsif member_id_type is distinct from profile_id_type then
      execute 'select count(*) from public.ride_members' into row_count;
      if row_count > 0 then
        raise exception 'public.ride_members.member_id is %, but public.profiles.id is %. Clear or migrate ride_members before changing this column type.',
          member_id_type, profile_id_type;
      end if;
      execute 'alter table public.ride_members drop constraint if exists ride_members_member_id_fkey';
      execute format('alter table public.ride_members alter column member_id drop not null');
      execute format('alter table public.ride_members alter column member_id type %s using null', profile_id_type);
    end if;

    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.ride_members'::regclass
        and contype = 'p'
    ) then
      execute 'update public.ride_members set id = gen_random_uuid() where id is null';
      execute 'alter table public.ride_members add primary key (id)';
    end if;
  end if;

  execute 'alter table public.ride_members add column if not exists role text not null default ''member''';
  execute 'alter table public.ride_members add column if not exists status text not null default ''approved''';
  execute 'alter table public.ride_members add column if not exists presence_status text default ''offline''';
  execute 'alter table public.ride_members add column if not exists last_seen_at timestamptz';
  execute 'alter table public.ride_members add column if not exists app_state text';
  execute 'alter table public.ride_members add column if not exists created_at timestamptz not null default now()';

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_members'
      and column_name = 'user_id'
  ) then
    execute 'update public.ride_members set member_id = user_id where member_id is null and user_id is not null';
  end if;

  execute 'alter table public.ride_members alter column member_id set not null';

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_member_id_fkey'
  ) then
    execute 'alter table public.ride_members add constraint ride_members_member_id_fkey foreign key (member_id) references public.profiles(id) on delete cascade';
  end if;

  if to_regclass('public.live_locations') is null then
    execute format($sql$
      create table public.live_locations (
        id uuid primary key default gen_random_uuid(),
        ride_id uuid not null references public.rides(id) on delete cascade,
        profile_id %s references public.profiles(id) on delete cascade,
        latitude double precision not null,
        longitude double precision not null,
        speed double precision,
        speed_mps double precision,
        heading double precision,
        battery text,
        signal text,
        user_name text not null default 'Rider',
        bike_name text not null default 'No bike added',
        avatar_url text,
        is_leader boolean not null default false,
        app_state text default 'tracking',
        accuracy double precision,
        queued_at timestamptz,
        updated_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
  else
    execute 'alter table public.live_locations add column if not exists id uuid default gen_random_uuid()';
    execute 'alter table public.live_locations add column if not exists ride_id uuid references public.rides(id) on delete cascade';

    select format_type(a.atttypid, a.atttypmod)
      into live_profile_id_type
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'live_locations'
      and a.attname = 'profile_id'
      and not a.attisdropped;

    if live_profile_id_type is null then
      execute format('alter table public.live_locations add column profile_id %s', profile_id_type);
    elsif live_profile_id_type is distinct from profile_id_type then
      execute 'select count(*) from public.live_locations' into row_count;
      if row_count > 0 then
        raise exception 'public.live_locations.profile_id is %, but public.profiles.id is %. Clear or migrate live_locations before changing this column type.',
          live_profile_id_type, profile_id_type;
      end if;
      execute 'alter table public.live_locations drop constraint if exists live_locations_profile_id_fkey';
      execute format('alter table public.live_locations alter column profile_id type %s using null', profile_id_type);
    end if;

    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.live_locations'::regclass
        and contype = 'p'
    ) then
      execute 'update public.live_locations set id = gen_random_uuid() where id is null';
      execute 'alter table public.live_locations add primary key (id)';
    end if;
  end if;

  execute 'alter table public.live_locations add column if not exists latitude double precision';
  execute 'alter table public.live_locations add column if not exists longitude double precision';
  execute 'alter table public.live_locations add column if not exists speed double precision';
  execute 'alter table public.live_locations add column if not exists speed_mps double precision';
  execute 'alter table public.live_locations add column if not exists heading double precision';
  execute 'alter table public.live_locations add column if not exists battery text';
  execute 'alter table public.live_locations add column if not exists signal text';
  execute 'alter table public.live_locations add column if not exists user_name text not null default ''Rider''';
  execute 'alter table public.live_locations add column if not exists bike_name text not null default ''No bike added''';
  execute 'alter table public.live_locations add column if not exists avatar_url text';
  execute 'alter table public.live_locations add column if not exists is_leader boolean not null default false';
  execute 'alter table public.live_locations add column if not exists app_state text default ''tracking''';
  execute 'alter table public.live_locations add column if not exists accuracy double precision';
  execute 'alter table public.live_locations add column if not exists queued_at timestamptz';
  execute 'alter table public.live_locations add column if not exists updated_at timestamptz not null default now()';

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'live_locations'
      and column_name = 'user_id'
  ) then
    execute 'update public.live_locations set profile_id = user_id where profile_id is null and user_id is not null';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.live_locations'::regclass
      and conname = 'live_locations_profile_id_fkey'
  ) then
    execute 'alter table public.live_locations add constraint live_locations_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade';
  end if;

  if to_regclass('public.ride_alerts') is null then
    execute format($sql$
      create table public.ride_alerts (
        id uuid primary key default gen_random_uuid(),
        ride_id uuid not null references public.rides(id) on delete cascade,
        profile_id %s references public.profiles(id) on delete set null,
        user_name text not null default 'Rider',
        type text not null default 'SOS',
        message text,
        latitude double precision,
        longitude double precision,
        created_at timestamptz not null default now()
      )
    $sql$, profile_id_type);
  else
    execute 'alter table public.ride_alerts add column if not exists id uuid default gen_random_uuid()';
    execute 'alter table public.ride_alerts add column if not exists ride_id uuid references public.rides(id) on delete cascade';

    select format_type(a.atttypid, a.atttypmod)
      into alert_profile_id_type
    from pg_attribute a
    join pg_class c on c.oid = a.attrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'ride_alerts'
      and a.attname = 'profile_id'
      and not a.attisdropped;

    if alert_profile_id_type is null then
      execute format('alter table public.ride_alerts add column profile_id %s', profile_id_type);
    elsif alert_profile_id_type is distinct from profile_id_type then
      execute 'select count(*) from public.ride_alerts' into row_count;
      if row_count > 0 then
        raise exception 'public.ride_alerts.profile_id is %, but public.profiles.id is %. Clear or migrate ride_alerts before changing this column type.',
          alert_profile_id_type, profile_id_type;
      end if;
      execute 'alter table public.ride_alerts drop constraint if exists ride_alerts_profile_id_fkey';
      execute format('alter table public.ride_alerts alter column profile_id type %s using null', profile_id_type);
    end if;

    if not exists (
      select 1 from pg_constraint
      where conrelid = 'public.ride_alerts'::regclass
        and contype = 'p'
    ) then
      execute 'update public.ride_alerts set id = gen_random_uuid() where id is null';
      execute 'alter table public.ride_alerts add primary key (id)';
    end if;
  end if;

  execute 'alter table public.ride_alerts add column if not exists user_name text not null default ''Rider''';
  execute 'alter table public.ride_alerts add column if not exists type text not null default ''SOS''';
  execute 'alter table public.ride_alerts add column if not exists message text';
  execute 'alter table public.ride_alerts add column if not exists latitude double precision';
  execute 'alter table public.ride_alerts add column if not exists longitude double precision';
  execute 'alter table public.ride_alerts add column if not exists created_at timestamptz not null default now()';

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ride_alerts'
      and column_name = 'user_id'
  ) then
    execute 'update public.ride_alerts set profile_id = user_id where profile_id is null and user_id is not null';
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_alerts'::regclass
      and conname = 'ride_alerts_profile_id_fkey'
  ) then
    execute 'alter table public.ride_alerts add constraint ride_alerts_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete set null';
  end if;
end $$;

delete from public.ride_members a
using public.ride_members b
where a.ctid < b.ctid
  and a.ride_id = b.ride_id
  and a.member_id = b.member_id;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.ride_members'::regclass
      and conname = 'ride_members_ride_id_member_id_key'
  ) then
    alter table public.ride_members
      add constraint ride_members_ride_id_member_id_key unique (ride_id, member_id);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.live_locations'::regclass
      and conname = 'live_locations_ride_id_profile_id_key'
  ) then
    alter table public.live_locations
      add constraint live_locations_ride_id_profile_id_key unique (ride_id, profile_id);
  end if;
end $$;

insert into public.ride_members (ride_id, member_id, role, status)
select r.id, p.id, 'host', 'approved'
from public.rides r
join public.profiles p on p.id::text = r.profile_id::text
where r.profile_id is not null
on conflict (ride_id, member_id) do update
set role = 'host',
    status = 'approved';

create index if not exists ride_members_member_status_idx
  on public.ride_members (member_id, status, created_at desc);

create index if not exists ride_members_radar_ride_idx
  on public.ride_members (ride_id);

create index if not exists live_locations_ride_updated_idx
  on public.live_locations (ride_id, updated_at desc);

create index if not exists live_locations_profile_updated_idx
  on public.live_locations (profile_id, updated_at desc);

create index if not exists ride_alerts_ride_created_idx
  on public.ride_alerts (ride_id, created_at desc);

alter table public.ride_members enable row level security;
alter table public.live_locations enable row level security;
alter table public.ride_alerts enable row level security;

drop policy if exists ride_members_authenticated_all on public.ride_members;
create policy ride_members_authenticated_all on public.ride_members
  for all to authenticated using (true) with check (true);

drop policy if exists live_locations_authenticated_all on public.live_locations;
create policy live_locations_authenticated_all on public.live_locations
  for all to authenticated using (true) with check (true);

drop policy if exists ride_alerts_authenticated_all on public.ride_alerts;
create policy ride_alerts_authenticated_all on public.ride_alerts
  for all to authenticated using (true) with check (true);

do $$
begin
  begin
    alter publication supabase_realtime add table public.ride_members;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.live_locations;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;

  begin
    alter publication supabase_realtime add table public.ride_alerts;
  exception
    when duplicate_object then null;
    when undefined_object then null;
  end;
end $$;

alter table if exists public.ride_members replica identity full;
alter table if exists public.live_locations replica identity full;
alter table if exists public.ride_alerts replica identity full;
