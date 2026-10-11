\set ON_ERROR_STOP on
do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
end $$;
create schema auth;
create schema supabase_migrations;
create table supabase_migrations.schema_migrations(version text primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),'')::jsonb,'{}'::jsonb)
$$;
grant usage on schema auth to anon,authenticated;
grant execute on function auth.uid(),auth.jwt() to anon,authenticated;

create table profiles(id bigint primary key, auth_user_id uuid unique, name text, bike text, avatar_url text);
create table users(id uuid primary key, name text);
create table rides(id uuid primary key, host_id uuid, title text, status text, ride_visibility text, max_riders int, created_at timestamptz, archived boolean default false, is_archived boolean default false, archived_at timestamptz);
create table participants(ride_id uuid, user_id uuid);
create table ride_members(id uuid primary key default gen_random_uuid(), ride_id uuid, member_id bigint, role text, status text, unique(ride_id,member_id));
create table live_locations(ride_id uuid, profile_id bigint, latitude float8, longitude float8, is_leader boolean default false, updated_at timestamptz, primary key(ride_id,profile_id));
create table ride_routes(ride_id uuid primary key, host_id bigint, start_label text, end_label text, stops jsonb, updated_at timestamptz);
create table ride_alerts(id uuid primary key default gen_random_uuid(), ride_id uuid, profile_id bigint, user_name text, type text, message text, avatar_url text, latitude float8, longitude float8, acknowledged_by text, original_alert_id uuid, created_at timestamptz default now());
create table ride_messages(id uuid primary key default gen_random_uuid(), ride_id uuid, user_id bigint, message text, created_at timestamptz default now());
create table notifications(id uuid primary key default gen_random_uuid(), profile_id bigint, ride_id uuid, title text, body text, created_at timestamptz default now());
create table ride_summaries(ride_id uuid primary key, host_id bigint, created_at timestamptz default now());

insert into profiles values
  (101,'a0000000-0000-0000-0000-000000000001','Host','Bike',null),
  (102,'a0000000-0000-0000-0000-000000000002','Rider','Bike',null);
insert into rides values('20000000-0000-0000-0000-0000000000a1','a0000000-0000-0000-0000-000000000001','Ride','active','public',10,now(),false,false,null);
insert into ride_members(ride_id,member_id,role,status) values('20000000-0000-0000-0000-0000000000a1',101,'host','approved');

alter table profiles enable row level security;
alter table users enable row level security;
alter table rides enable row level security;
alter table participants enable row level security;
alter table ride_members enable row level security;
alter table live_locations enable row level security;
alter table ride_routes enable row level security;
alter table ride_alerts enable row level security;
alter table ride_messages enable row level security;
alter table notifications enable row level security;
alter table ride_summaries enable row level security;
create policy profiles_open on profiles for all to authenticated using(true) with check(true);
create policy rides_open on rides for all to authenticated using(true) with check(true);
create policy members_open on ride_members for all to authenticated using(true) with check(true);
create policy locations_open on live_locations for all to authenticated using(true) with check(true);
create policy alerts_open on ride_alerts for all to authenticated using(true) with check(true);

create function public.create_ride_alert_sos(text,text,text,text,double precision,double precision,boolean)
returns jsonb language sql as $$ select '{}'::jsonb $$;
