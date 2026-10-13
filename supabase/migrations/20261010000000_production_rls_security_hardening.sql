-- JourneySync production authorization hardening.
--
-- Forward-only and data preserving. This migration intentionally aborts when
-- the canonical auth/profile relationship is absent; do not weaken these
-- preconditions to make an unknown production schema accept the migration.

begin;

do $$
declare
  missing text[] := array[]::text[];
begin
  if to_regclass('public.profiles') is null then missing := array_append(missing,'profiles'); end if;
  if to_regclass('public.rides') is null then missing := array_append(missing,'rides'); end if;
  if to_regclass('public.ride_members') is null then missing := array_append(missing,'ride_members'); end if;
  if to_regclass('public.live_locations') is null then missing := array_append(missing,'live_locations'); end if;
  if to_regclass('public.ride_routes') is null then missing := array_append(missing,'ride_routes'); end if;
  if to_regclass('public.ride_alerts') is null then missing := array_append(missing,'ride_alerts'); end if;
  if cardinality(missing) > 0 then
    raise exception 'JourneySync RLS hardening aborted; missing tables: %', array_to_string(missing, ', ');
  end if;

  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='id')
     or not exists (select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='auth_user_id') then
    raise exception 'JourneySync RLS hardening aborted; profiles.id/auth_user_id identity mapping is required';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ride_members' and column_name='member_id')
     or not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ride_members' and column_name='status') then
    raise exception 'JourneySync RLS hardening aborted; canonical ride_members.member_id/status is required';
  end if;
  if not exists (select 1 from information_schema.columns where table_schema='public' and table_name='live_locations' and column_name='profile_id') then
    raise exception 'JourneySync RLS hardening aborted; live_locations.profile_id is required';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='rides'
      and column_name='id' and udt_name<>'uuid'
  ) then
    raise exception 'JourneySync RLS hardening aborted; rides.id must be uuid';
  end if;
  if exists (
    select 1
    from information_schema.columns profile_key
    join information_schema.columns dependent_key
      on dependent_key.table_schema='public'
     and dependent_key.column_name in ('member_id','profile_id')
     and dependent_key.table_name in ('ride_members','live_locations','ride_alerts')
    where profile_key.table_schema='public'
      and profile_key.table_name='profiles'
      and profile_key.column_name='id'
      and dependent_key.udt_name<>profile_key.udt_name
  ) then
    raise exception 'JourneySync RLS hardening aborted; profile foreign-key column types do not match profiles.id';
  end if;
end $$;

-- These helpers bypass table RLS only to answer narrow authorization questions.
-- They never accept a caller-controlled identity as proof of ownership.
create or replace function public.js_current_profile_id()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.id::text
  from public.profiles p
  where auth.uid() is not null
    and (
      p.auth_user_id::text = auth.uid()::text
      or (p.auth_user_id is null and p.id::text = auth.uid()::text)
    )
  order by (p.auth_user_id is not null) desc
  limit 1
$$;

create or replace function public.js_is_admin()
returns boolean
language sql
stable
security invoker
set search_path = pg_catalog
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') = 'admin'
$$;

create or replace function public.js_is_ride_host(target_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.js_current_profile_id() is not null and exists (
    select 1 from public.rides r
    where r.id = target_ride_id
      and (
        public.js_current_profile_id() = any (array[
        coalesce(to_jsonb(r)->>'host_id', ''),
        coalesce(to_jsonb(r)->>'profile_id', ''),
        coalesce(to_jsonb(r)->>'creator_id', ''),
        coalesce(to_jsonb(r)->>'user_id', '')
        ])
        or auth.uid()::text = any (array[
          coalesce(to_jsonb(r)->>'host_id', ''),
          coalesce(to_jsonb(r)->>'profile_id', ''),
          coalesce(to_jsonb(r)->>'creator_id', ''),
          coalesce(to_jsonb(r)->>'user_id', '')
        ])
      )
  )
$$;

create or replace function public.js_is_approved_ride_member(target_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.js_current_profile_id() is not null and exists (
    select 1 from public.ride_members rm
    where rm.ride_id = target_ride_id
      and rm.member_id::text = public.js_current_profile_id()
      and lower(coalesce(rm.status, 'approved')) in ('approved', 'joined', 'active')
  )
$$;

create or replace function public.js_is_ride_participant(target_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.js_is_ride_host(target_ride_id)
      or public.js_is_approved_ride_member(target_ride_id)
$$;

-- Some production-era tracking tables retained text ride identifiers even
-- though rides.id is UUID. Keep policy calls type-safe without accepting an
-- invalid identifier or weakening the canonical UUID authorization check.
create or replace function public.js_is_ride_host(target_ride_id text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when target_ride_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.js_is_ride_host(target_ride_id::uuid)
    else false
  end
$$;

create or replace function public.js_is_approved_ride_member(target_ride_id text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when target_ride_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.js_is_approved_ride_member(target_ride_id::uuid)
    else false
  end
$$;

create or replace function public.js_is_ride_participant(target_ride_id text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
    when target_ride_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then public.js_is_ride_participant(target_ride_id::uuid)
    else false
  end
$$;

create or replace function public.js_is_public_discoverable_ride(target_ride_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.rides r
    where r.id = target_ride_id
      and lower(coalesce(to_jsonb(r)->>'ride_visibility', 'public')) = 'public'
      and lower(coalesce(to_jsonb(r)->>'status', 'scheduled')) in ('scheduled', 'planned', 'active')
      and coalesce((nullif(to_jsonb(r)->>'archived', ''))::boolean, false) = false
      and coalesce((nullif(to_jsonb(r)->>'is_archived', ''))::boolean, false) = false
      and nullif(to_jsonb(r)->>'archived_at', '') is null
  )
$$;

revoke all on function public.js_current_profile_id() from public, anon;
revoke all on function public.js_is_admin() from public, anon;
revoke all on function public.js_is_ride_host(uuid) from public, anon;
revoke all on function public.js_is_approved_ride_member(uuid) from public, anon;
revoke all on function public.js_is_ride_participant(uuid) from public, anon;
revoke all on function public.js_is_ride_host(text) from public, anon;
revoke all on function public.js_is_approved_ride_member(text) from public, anon;
revoke all on function public.js_is_ride_participant(text) from public, anon;
revoke all on function public.js_is_public_discoverable_ride(uuid) from public;
grant execute on function public.js_current_profile_id() to authenticated;
grant execute on function public.js_is_admin() to authenticated;
grant execute on function public.js_is_ride_host(uuid) to authenticated;
grant execute on function public.js_is_approved_ride_member(uuid) to authenticated;
grant execute on function public.js_is_ride_participant(uuid) to authenticated;
grant execute on function public.js_is_ride_host(text) to authenticated;
grant execute on function public.js_is_approved_ride_member(text) to authenticated;
grant execute on function public.js_is_ride_participant(text) to authenticated;
grant execute on function public.js_is_public_discoverable_ride(uuid) to anon, authenticated;

-- Repair the legacy helper names because deployed clients and the SOS fallback
-- RPC may still call them. The supplied profile must belong to auth.uid().
create or replace function public.current_profile_id_text()
returns text language sql stable security definer
set search_path = pg_catalog, public
as $$ select public.js_current_profile_id() $$;

create or replace function public.is_ride_participant_text(target_ride_id text)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$ select target_ride_id ~* '^[0-9a-f-]{36}$' and public.js_is_ride_participant(target_ride_id::uuid) $$;

create or replace function public.is_ride_host_text(target_ride_id text)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$ select target_ride_id ~* '^[0-9a-f-]{36}$' and public.js_is_ride_host(target_ride_id::uuid) $$;

create or replace function public.profile_is_ride_participant_text(target_ride_id text, target_profile_id text)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select target_profile_id = public.js_current_profile_id()
     and target_ride_id ~* '^[0-9a-f-]{36}$'
     and public.js_is_ride_participant(target_ride_id::uuid)
$$;

create or replace function public.profile_is_ride_host_text(target_ride_id text, target_profile_id text)
returns boolean language sql stable security definer
set search_path = pg_catalog, public
as $$
  select target_profile_id = public.js_current_profile_id()
     and target_ride_id ~* '^[0-9a-f-]{36}$'
     and public.js_is_ride_host(target_ride_id::uuid)
$$;

revoke all on function public.current_profile_id_text() from public, anon;
revoke all on function public.is_ride_participant_text(text) from public, anon;
revoke all on function public.is_ride_host_text(text) from public, anon;
revoke all on function public.profile_is_ride_participant_text(text,text) from public, anon;
revoke all on function public.profile_is_ride_host_text(text,text) from public, anon;
grant execute on function public.current_profile_id_text() to authenticated;
grant execute on function public.is_ride_participant_text(text) to authenticated;
grant execute on function public.is_ride_host_text(text) to authenticated;
grant execute on function public.profile_is_ride_participant_text(text,text) to authenticated;
grant execute on function public.profile_is_ride_host_text(text,text) to authenticated;

-- A private ride can only be joined with its access code. Public discovery can
-- join directly. Capacity and identity are enforced atomically server-side.
create or replace function public.request_ride_join(
  p_ride_id uuid,
  p_access_code text default null
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  rider_id text := public.js_current_profile_id();
  ride_row public.rides%rowtype;
  visibility text;
  ride_status text;
  expected_code text;
  approved_count integer;
  existing_status text;
begin
  if rider_id is null then raise exception 'Authenticated profile required' using errcode='42501'; end if;
  select * into ride_row from public.rides where id=p_ride_id for update;
  if not found then raise exception 'Ride not found' using errcode='P0002'; end if;
  if public.js_is_ride_host(p_ride_id) then return 'already_joined'; end if;

  visibility := lower(coalesce(to_jsonb(ride_row)->>'ride_visibility', 'public'));
  ride_status := lower(coalesce(to_jsonb(ride_row)->>'status', 'scheduled'));
  if ride_status not in ('scheduled','planned','active') then raise exception 'Ride is not joinable' using errcode='42501'; end if;
  if coalesce((to_jsonb(ride_row)->>'archived')::boolean,false)
     or coalesce((to_jsonb(ride_row)->>'is_archived')::boolean,false)
     or nullif(to_jsonb(ride_row)->>'archived_at','') is not null then
    raise exception 'Ride is archived' using errcode='42501';
  end if;

  expected_code := 'JS-' || right(upper(regexp_replace(p_ride_id::text, '[^A-Za-z0-9]', '', 'g')), 4);
  if visibility <> 'public' and upper(regexp_replace(coalesce(p_access_code,''), '\s', '', 'g')) <> expected_code then
    raise exception 'Valid ride access code required' using errcode='42501';
  end if;

  select status into existing_status from public.ride_members
   where ride_id=p_ride_id and member_id::text=rider_id limit 1;
  if lower(coalesce(existing_status,'')) in ('approved','joined','active') then return 'already_joined'; end if;
  if lower(coalesce(existing_status,'')) = 'pending' then return 'already_requested'; end if;

  select count(*) into approved_count from public.ride_members
   where ride_id=p_ride_id and lower(coalesce(status,'approved')) in ('approved','joined','active');
  if nullif(to_jsonb(ride_row)->>'max_riders','') is not null
     and approved_count >= (to_jsonb(ride_row)->>'max_riders')::integer then
    raise exception 'Ride is full' using errcode='23514';
  end if;

  insert into public.ride_members(ride_id,member_id,role,status)
  select p_ride_id,p.id,'member','approved'
  from public.profiles p where p.id::text=rider_id
  on conflict(ride_id,member_id) do update set status='approved', role='member';
  return 'joined';
end $$;

revoke all on function public.request_ride_join(uuid,text) from public, anon;
grant execute on function public.request_ride_join(uuid,text) to authenticated;

create or replace function public.join_ride_by_access_code(p_access_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  normalized_code text := upper(regexp_replace(coalesce(p_access_code,''), '\s', '', 'g'));
  matched public.rides%rowtype;
  join_result text;
begin
  if normalized_code !~ '^JS-[A-Z0-9]{4}$' then
    raise exception 'Invalid ride access code' using errcode='22023';
  end if;
  select r.* into matched
  from public.rides r
  where 'JS-' || right(upper(regexp_replace(r.id::text,'[^A-Za-z0-9]','','g')),4)=normalized_code
    and lower(coalesce(to_jsonb(r)->>'status','scheduled')) in ('scheduled','planned','active')
    and not coalesce((nullif(to_jsonb(r)->>'archived',''))::boolean,false)
    and not coalesce((nullif(to_jsonb(r)->>'is_archived',''))::boolean,false)
    and nullif(to_jsonb(r)->>'archived_at','') is null
  order by coalesce((to_jsonb(r)->>'created_at')::timestamptz, now()) desc
  limit 1;
  if not found then raise exception 'Ride not found or no longer joinable' using errcode='P0002'; end if;
  join_result := public.request_ride_join(matched.id, normalized_code);
  return jsonb_build_object(
    'status', join_result,
    'ride_id', matched.id,
    'title', coalesce(nullif(to_jsonb(matched)->>'title',''),nullif(to_jsonb(matched)->>'name',''),'Ride'),
    'ride_status', coalesce(to_jsonb(matched)->>'status','scheduled')
  );
end $$;

revoke all on function public.join_ride_by_access_code(text) from public, anon;
grant execute on function public.join_ride_by_access_code(text) to authenticated;

-- Replace every accumulated policy on protected tables. PostgreSQL ORs
-- permissive policies, so leaving even one historical USING(true) is unsafe.
do $$
declare t text; p record;
begin
  foreach t in array array['profiles','users','rides','participants','ride_members','live_locations','ride_routes','ride_alerts','ride_messages','notifications','ride_summaries'] loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I enable row level security',t);
      for p in select policyname from pg_policies where schemaname='public' and tablename=t loop
        execute format('drop policy %I on public.%I',p.policyname,t);
      end loop;
    end if;
  end loop;
end $$;

-- The historical release migration used this compatibility helper only while
-- its temporary policies were active. All of those policies were dropped
-- above, so remove the helper before installing the authoritative model.
drop function if exists public.js_release_profile_id();

create policy profiles_self_select on public.profiles for select to authenticated
  using (id::text=public.js_current_profile_id());
create policy profiles_ride_peer_select on public.profiles for select to authenticated
  using (exists (
    select 1 from public.ride_members rm
    where rm.member_id::text=profiles.id::text
      and lower(coalesce(rm.status,'approved')) in ('approved','joined','active')
      and public.js_is_ride_participant(rm.ride_id)
  ));
create policy profiles_self_insert on public.profiles for insert to authenticated
  with check (auth_user_id=auth.uid());
create policy profiles_self_update on public.profiles for update to authenticated
  using (id::text=public.js_current_profile_id())
  with check (id::text=public.js_current_profile_id() and auth_user_id=auth.uid());
create policy profiles_admin_select on public.profiles for select to authenticated
  using (public.js_is_admin());

do $$ begin
  if to_regclass('public.users') is not null then
    execute 'create policy legacy_users_self_select on public.users for select to authenticated using (id::text=public.js_current_profile_id())';
    execute 'create policy legacy_users_self_update on public.users for update to authenticated using (id::text=public.js_current_profile_id()) with check (id::text=public.js_current_profile_id())';
    execute 'create policy legacy_users_admin_select on public.users for select to authenticated using (public.js_is_admin())';
  end if;
  if to_regclass('public.participants') is not null then
    execute 'create policy legacy_participants_scoped_select on public.participants for select to authenticated using (user_id::text=public.js_current_profile_id() or public.js_is_ride_host(ride_id) or public.js_is_ride_participant(ride_id))';
  end if;
end $$;

-- Public discovery needs a host name/avatar, never the underlying profile row
-- containing phone, emergency contacts, device tokens, or preferences.
drop view if exists public.profile_summaries;
create view public.profile_summaries
with (security_barrier=true, security_invoker=false)
as
select p.id, p.name, p.bike, p.avatar_url
from public.profiles p
where p.id::text=public.js_current_profile_id()
   or exists (
     select 1 from public.ride_members rm
     where rm.member_id::text=p.id::text
       and lower(coalesce(rm.status,'approved')) in ('approved','joined','active')
       and public.js_is_ride_participant(rm.ride_id)
   )
   or exists (
     select 1 from public.rides r
     where public.js_is_public_discoverable_ride(r.id)
       and (p.id::text=any(array[coalesce(to_jsonb(r)->>'host_id',''),coalesce(to_jsonb(r)->>'profile_id',''),coalesce(to_jsonb(r)->>'creator_id',''),coalesce(to_jsonb(r)->>'user_id','')])
         or coalesce(to_jsonb(p)->>'auth_user_id','')=any(array[coalesce(to_jsonb(r)->>'host_id',''),coalesce(to_jsonb(r)->>'profile_id',''),coalesce(to_jsonb(r)->>'creator_id',''),coalesce(to_jsonb(r)->>'user_id','')]))
   );
revoke all on public.profile_summaries from public;
grant select on public.profile_summaries to anon, authenticated;

create policy rides_participant_select on public.rides for select to authenticated
  using (public.js_is_ride_participant(id));
create policy rides_host_insert on public.rides for insert to authenticated
  with check (public.js_current_profile_id() is not null and (public.js_current_profile_id() = any(array[coalesce(to_jsonb(rides)->>'host_id',''),coalesce(to_jsonb(rides)->>'profile_id',''),coalesce(to_jsonb(rides)->>'creator_id',''),coalesce(to_jsonb(rides)->>'user_id','')]) or auth.uid()::text = any(array[coalesce(to_jsonb(rides)->>'host_id',''),coalesce(to_jsonb(rides)->>'profile_id',''),coalesce(to_jsonb(rides)->>'creator_id',''),coalesce(to_jsonb(rides)->>'user_id','')])));
create policy rides_host_update on public.rides for update to authenticated
  using (public.js_is_ride_host(id)) with check (public.js_is_ride_host(id));
create policy rides_host_delete on public.rides for delete to authenticated
  using (public.js_is_ride_host(id));
create policy rides_admin_select on public.rides for select to authenticated
  using (public.js_is_admin());

drop view if exists public.ride_discovery;
create view public.ride_discovery
with (security_barrier=true, security_invoker=false)
as
select
  r.id,
  coalesce(to_jsonb(r)->>'host_id',to_jsonb(r)->>'profile_id',to_jsonb(r)->>'creator_id',to_jsonb(r)->>'user_id') as host_id,
  coalesce(nullif(to_jsonb(r)->>'title',''),nullif(to_jsonb(r)->>'name',''),'Ride') as title,
  coalesce(to_jsonb(r)->>'start_location',to_jsonb(r)->>'start','') as start_location,
  coalesce(to_jsonb(r)->>'end_location',to_jsonb(r)->>'destination','') as end_location,
  coalesce(to_jsonb(r)->>'status','scheduled') as status,
  nullif(to_jsonb(r)->>'created_at','')::timestamptz as created_at,
  nullif(to_jsonb(r)->>'ended_at','')::timestamptz as ended_at,
  coalesce(to_jsonb(r)->>'ride_visibility','public') as ride_visibility,
  coalesce(to_jsonb(r)->>'ride_mode','group') as ride_mode,
  nullif(to_jsonb(r)->>'archived_at','')::timestamptz as archived_at,
  coalesce((nullif(to_jsonb(r)->>'archived',''))::boolean,false) as archived,
  coalesce((nullif(to_jsonb(r)->>'is_archived',''))::boolean,false) as is_archived,
  nullif(to_jsonb(r)->>'max_riders','')::integer as max_riders
from public.rides r
where public.js_is_public_discoverable_ride(r.id);
revoke all on public.ride_discovery from public;
grant select on public.ride_discovery to anon,authenticated;

create policy ride_members_select on public.ride_members for select to authenticated
  using (member_id::text=public.js_current_profile_id() or public.js_is_ride_host(ride_id)
    or (public.js_is_ride_participant(ride_id) and lower(coalesce(status,'approved')) in ('approved','joined','active')));
create policy ride_members_host_update on public.ride_members for update to authenticated
  using (public.js_is_ride_host(ride_id)) with check (
    public.js_is_ride_host(ride_id) and role='member'
    and lower(status) in ('pending','approved','rejected','removed','cancelled')
  );
create policy ride_members_self_or_host_delete on public.ride_members for delete to authenticated
  using (member_id::text=public.js_current_profile_id() or public.js_is_ride_host(ride_id));

create or replace function public.js_protect_membership_identity()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if current_user not in ('postgres','service_role','supabase_admin') and (
    new.ride_id is distinct from old.ride_id
    or new.member_id is distinct from old.member_id
    or new.role is distinct from old.role
  ) then
    raise exception 'Membership identity and role are immutable' using errcode='42501';
  end if;
  return new;
end $$;
drop trigger if exists js_protect_membership_identity on public.ride_members;
create trigger js_protect_membership_identity before update on public.ride_members
for each row execute function public.js_protect_membership_identity();
revoke all on function public.js_protect_membership_identity() from public, anon, authenticated;

create policy live_locations_participant_select on public.live_locations for select to authenticated
  using (public.js_is_ride_participant(ride_id));
create policy live_locations_self_insert on public.live_locations for insert to authenticated
  with check (public.js_is_ride_participant(ride_id) and profile_id::text=public.js_current_profile_id()
    and coalesce(is_leader,false)=public.js_is_ride_host(ride_id));
create policy live_locations_self_update on public.live_locations for update to authenticated
  using (profile_id::text=public.js_current_profile_id())
  with check (public.js_is_ride_participant(ride_id) and profile_id::text=public.js_current_profile_id()
    and coalesce(is_leader,false)=public.js_is_ride_host(ride_id));
create policy live_locations_self_delete on public.live_locations for delete to authenticated
  using (profile_id::text=public.js_current_profile_id() or public.js_is_ride_host(ride_id));

create policy ride_routes_participant_select on public.ride_routes for select to authenticated
  using (public.js_is_ride_participant(ride_id));
create policy ride_routes_host_insert on public.ride_routes for insert to authenticated
  with check (public.js_is_ride_host(ride_id));
create policy ride_routes_host_update on public.ride_routes for update to authenticated
  using (public.js_is_ride_host(ride_id)) with check (public.js_is_ride_host(ride_id));
create policy ride_routes_host_delete on public.ride_routes for delete to authenticated
  using (public.js_is_ride_host(ride_id));

create policy ride_alerts_participant_select on public.ride_alerts for select to authenticated
  using (public.js_is_ride_participant(ride_id));
create policy ride_alerts_participant_insert on public.ride_alerts for insert to authenticated
  with check (public.js_is_ride_participant(ride_id) and (
    (lower(coalesce(type,'sos')) in ('sos','safe') and profile_id::text=public.js_current_profile_id())
    or (lower(coalesce(type,'')) in ('sos_acknowledged','group_sos') and public.js_is_ride_host(ride_id))
    or (lower(coalesce(type,''))='group_acknowledged' and coalesce(acknowledged_by,'')=public.js_current_profile_id())
  ));

do $$ begin
  if to_regclass('public.ride_messages') is not null then
    execute 'create policy ride_messages_participant_select on public.ride_messages for select to authenticated using (public.js_is_ride_participant(ride_id))';
    execute 'create policy ride_messages_self_insert on public.ride_messages for insert to authenticated with check (public.js_is_ride_participant(ride_id) and user_id::text=public.js_current_profile_id())';
    execute 'create policy ride_messages_self_delete on public.ride_messages for delete to authenticated using (user_id::text=public.js_current_profile_id() or public.js_is_ride_host(ride_id))';
  end if;
  if to_regclass('public.notifications') is not null then
    execute 'create policy notifications_owner_select on public.notifications for select to authenticated using (profile_id::text=public.js_current_profile_id())';
    execute 'create policy notifications_ride_insert on public.notifications for insert to authenticated with check (profile_id::text=public.js_current_profile_id() or (ride_id is not null and public.js_is_ride_participant(ride_id) and exists(select 1 from public.ride_members rm where rm.ride_id=notifications.ride_id and rm.member_id=notifications.profile_id and lower(coalesce(rm.status,''approved'')) in (''approved'',''joined'',''active''))))';
    execute 'create policy notifications_owner_update on public.notifications for update to authenticated using (profile_id::text=public.js_current_profile_id()) with check (profile_id::text=public.js_current_profile_id())';
    execute 'create policy notifications_owner_delete on public.notifications for delete to authenticated using (profile_id::text=public.js_current_profile_id())';
  end if;
  if to_regclass('public.ride_summaries') is not null then
    execute 'create policy ride_summaries_participant_select on public.ride_summaries for select to authenticated using (public.js_is_ride_participant(ride_id))';
    execute 'create policy ride_summaries_host_insert on public.ride_summaries for insert to authenticated with check (public.js_is_ride_host(ride_id))';
    execute 'create policy ride_summaries_host_update on public.ride_summaries for update to authenticated using (public.js_is_ride_host(ride_id)) with check (public.js_is_ride_host(ride_id))';
    execute 'create policy ride_summaries_host_delete on public.ride_summaries for delete to authenticated using (public.js_is_ride_host(ride_id))';
  end if;
end $$;

-- Table grants are explicit; RLS remains the row-level authority.
revoke all on public.profiles, public.rides, public.ride_members, public.live_locations, public.ride_routes, public.ride_alerts from public, anon;
grant select,insert,update on public.profiles to authenticated;
grant select,insert,update,delete on public.rides,public.ride_members,public.live_locations,public.ride_routes to authenticated;
grant select,insert on public.ride_alerts to authenticated;
do $$ begin
  if to_regclass('public.users') is not null then
    execute 'revoke all on public.users from public, anon';
    execute 'grant select,update on public.users to authenticated';
  end if;
  if to_regclass('public.participants') is not null then
    execute 'revoke all on public.participants from public, anon';
    execute 'grant select on public.participants to authenticated';
  end if;
  if to_regclass('public.ride_messages') is not null then
    execute 'revoke all on public.ride_messages from public, anon';
    execute 'grant select,insert,delete on public.ride_messages to authenticated';
  end if;
  if to_regclass('public.notifications') is not null then
    execute 'revoke all on public.notifications from public, anon';
    execute 'grant select,insert,update,delete on public.notifications to authenticated';
  end if;
  if to_regclass('public.ride_summaries') is not null then
    execute 'revoke all on public.ride_summaries from public, anon';
    execute 'grant select,insert,update,delete on public.ride_summaries to authenticated';
  end if;
end $$;

-- Lock down the SOS RPC itself. The replacement participant helper above binds
-- p_profile_id to auth.uid(), closing the impersonation path.
create or replace function public.create_ride_alert_sos(
  p_ride_id text,
  p_profile_id text,
  p_profile_name text,
  p_avatar_url text default '',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_broadcast_to_group boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare inserted jsonb;
begin
  if p_ride_id !~* '^[0-9a-f-]{36}$' or p_profile_id <> public.js_current_profile_id() then
    raise exception 'SOS identity does not match the authenticated rider' using errcode='42501';
  end if;
  if not public.js_is_ride_participant(p_ride_id::uuid) then
    raise exception 'Rider is not an approved ride participant' using errcode='42501';
  end if;
  if p_broadcast_to_group and not public.js_is_ride_host(p_ride_id::uuid) then
    raise exception 'Only the ride host can broadcast a group SOS' using errcode='42501';
  end if;
  insert into public.ride_alerts(
    ride_id,profile_id,user_name,type,message,avatar_url,latitude,longitude,created_at
  ) values (
    p_ride_id::uuid,(select p.id from public.profiles p where p.id::text=p_profile_id),
    coalesce(nullif(trim(p_profile_name),''),'Rider'),
    case when p_broadcast_to_group then 'group_sos' else 'sos' end,
    case when p_broadcast_to_group then 'SOS alert broadcast to the ride group' else 'SOS alert triggered' end,
    coalesce(p_avatar_url,''),p_latitude,p_longitude,now()
  ) returning to_jsonb(ride_alerts.*) into inserted;
  return inserted;
end $$;

revoke all on function public.create_ride_alert_sos(text,text,text,text,double precision,double precision,boolean) from public, anon;
grant execute on function public.create_ride_alert_sos(text,text,text,text,double precision,double precision,boolean) to authenticated;

commit;
