\set ON_ERROR_STOP on

do $$ begin
  if not exists(select 1 from pg_roles where rolname='anon') then create role anon nologin; end if;
  if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin; end if;
  if not exists(select 1 from pg_roles where rolname='service_role') then create role service_role nologin bypassrls; end if;
end $$;
create schema auth;
create schema supabase_migrations;
create table supabase_migrations.schema_migrations(version text primary key);

create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
$$;
grant usage on schema auth to anon,authenticated;
grant execute on function auth.uid(),auth.jwt() to anon,authenticated;

create table public.profiles(
  id uuid primary key, auth_user_id uuid unique, phone text, name text,
  bike text, avatar_url text, emergency_contacts jsonb, fcm_token text,
  active_ride_id uuid
);
create table public.users(
  id uuid primary key, name text, phone text, current_lat double precision,
  current_lng double precision, active_ride_id uuid
);
create table public.rides(
  id uuid primary key, host_id uuid references profiles(id), title text,
  status text, ride_visibility text, max_riders integer, created_at timestamptz,
  archived boolean default false, is_archived boolean default false,
  archived_at timestamptz
);
alter table profiles add constraint profiles_active_ride_fk foreign key(active_ride_id) references rides(id);
alter table users add constraint users_active_ride_fk foreign key(active_ride_id) references rides(id);
create table public.participants(
  ride_id uuid references rides(id), user_id uuid references users(id),
  primary key(ride_id,user_id)
);
create table public.ride_members(
  id uuid primary key default gen_random_uuid(), ride_id uuid references rides(id), member_id uuid references profiles(id),
  role text, status text, presence_status text, created_at timestamptz default now(),
  unique(ride_id,member_id)
);
create table public.live_locations(
  ride_id uuid references rides(id), profile_id uuid references profiles(id),
  latitude double precision, longitude double precision, is_leader boolean default false,
  updated_at timestamptz default now(), primary key(ride_id,profile_id)
);
create table public.ride_routes(
  ride_id uuid primary key references rides(id), host_id uuid references profiles(id),
  start_label text, end_label text, stops jsonb, updated_at timestamptz
);
create table public.ride_alerts(
  id uuid primary key default gen_random_uuid(), ride_id uuid references rides(id),
  profile_id uuid references profiles(id), user_name text, type text, message text,
  avatar_url text, latitude double precision, longitude double precision,
  acknowledged_by text, original_alert_id uuid, created_at timestamptz default now()
);
create table public.ride_messages(
  id uuid primary key default gen_random_uuid(), ride_id uuid references rides(id),
  user_id uuid references profiles(id), message text, created_at timestamptz default now()
);
create table public.notifications(
  id uuid primary key default gen_random_uuid(), profile_id uuid references profiles(id),
  ride_id uuid references rides(id), title text, body text, read boolean default false,
  created_at timestamptz default now()
);
create table public.ride_summaries(
  ride_id uuid primary key references rides(id), host_id uuid references profiles(id),
  distance_km double precision, created_at timestamptz default now()
);

-- Simulate the accumulated vulnerable production policies.
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
create policy rides_authenticated_all on rides for all to authenticated using(true) with check(true);
create policy users_all on users for all using(true) with check(true);
create policy participants_all on participants for all using(true) with check(true);
create policy ride_members_authenticated_all on ride_members for all to authenticated using(true) with check(true);
create policy live_locations_authenticated_all on live_locations for all to authenticated using(true) with check(true);
create policy ride_routes_authenticated_all on ride_routes for all to authenticated using(true) with check(true);
create policy ride_alerts_authenticated_all on ride_alerts for all to authenticated using(true) with check(true);
create policy ride_messages_select_all on ride_messages for select using(true);
create policy ride_messages_insert_all on ride_messages for insert with check(true);
create policy notifications_authenticated_all on notifications for all to authenticated using(true) with check(true);
create policy ride_summaries_authenticated_all on ride_summaries for all to authenticated using(true) with check(true);

create function public.create_ride_alert_sos(text,text,text,text,double precision,double precision,boolean)
returns jsonb language sql as $$ select '{}'::jsonb $$;

insert into profiles(id,auth_user_id,phone,name,bike,emergency_contacts,fcm_token) values
('10000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000001','100','Host A','A','[]','secret-a'),
('10000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000002','200','Rider A','A','[]','secret-b'),
('10000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000003','300','Host B','B','[]','secret-c'),
('10000000-0000-0000-0000-000000000004','a0000000-0000-0000-0000-000000000004','400','Rider B','B','[]','secret-d'),
('10000000-0000-0000-0000-000000000005','a0000000-0000-0000-0000-000000000005','500','Pending','P','[]','secret-e'),
('10000000-0000-0000-0000-000000000006','a0000000-0000-0000-0000-000000000006','600','Outsider','O','[]','secret-f');
insert into rides(id,host_id,title,status,ride_visibility,max_riders,created_at) values
('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000001','Ride A','active','public',10,now()),
('20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000003','Ride B','active','private',10,now()),
('20000000-0000-0000-0000-0000000000c3','10000000-0000-0000-0000-000000000003','Old','completed','public',10,now());
insert into users(id,name,phone,current_lat,current_lng) values
('10000000-0000-0000-0000-000000000001','Host A','100',12,77),
('10000000-0000-0000-0000-000000000002','Rider A','200',12.1,77.1),
('10000000-0000-0000-0000-000000000004','Rider B','400',13,78);
insert into participants values
('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002'),
('20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000004');
insert into ride_members(id,ride_id,member_id,role,status) values
('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','member','approved'),
('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000005','member','pending'),
('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000004','member','approved');
insert into live_locations values
('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002',12,77,false,now()),
('20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000004',13,78,false,now());
insert into ride_routes values
('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000001','a','b','[]',now()),
('20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000003','c','d','[]',now());
insert into ride_alerts(ride_id,profile_id,user_name,type) values
('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','Rider A','sos'),
('20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000004','Rider B','sos');
insert into ride_messages(ride_id,user_id,message) values
('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002','A'),
('20000000-0000-0000-0000-0000000000b2','10000000-0000-0000-0000-000000000004','B');
