-- JourneySync SOS RPC fallback for production RLS/schema drift.

alter table public.ride_alerts
  add column if not exists user_name text,
  add column if not exists type text not null default 'sos',
  add column if not exists message text,
  add column if not exists avatar_url text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists created_at timestamptz not null default now();

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
set search_path = public
as $$
declare
  profile_id_type text;
  inserted jsonb;
  alert_type text := case when p_broadcast_to_group then 'group_sos' else 'sos' end;
  alert_message text := case
    when p_broadcast_to_group then 'SOS alert broadcast to the ride group'
    else 'SOS alert triggered'
  end;
begin
  if trim(coalesce(p_ride_id, '')) = ''
     or trim(coalesce(p_profile_id, '')) = '' then
    raise exception 'SOS alert requires ride and rider.';
  end if;

  if not public.profile_is_ride_participant_text(p_ride_id, p_profile_id) then
    raise exception 'This rider is not part of this ride.';
  end if;

  select format_type(a.atttypid, a.atttypmod)
    into profile_id_type
  from pg_attribute a
  where a.attrelid = 'public.ride_alerts'::regclass
    and a.attname = 'profile_id'
    and a.attnum > 0
    and not a.attisdropped;

  if profile_id_type is null then
    profile_id_type := 'text';
  end if;

  execute format(
    'insert into public.ride_alerts (
       ride_id,
       profile_id,
       user_name,
       type,
       message,
       avatar_url,
       latitude,
       longitude,
       created_at
     )
     values (
       $1::uuid,
       $2::%s,
       $3,
       $4,
       $5,
       $6,
       $7,
       $8,
       now()
     )
     returning to_jsonb(public.ride_alerts.*)',
    profile_id_type
  )
  using
    p_ride_id,
    p_profile_id,
    coalesce(nullif(trim(p_profile_name), ''), 'Rider'),
    alert_type,
    alert_message,
    coalesce(p_avatar_url, ''),
    p_latitude,
    p_longitude
  into inserted;

  return inserted;
end;
$$;

grant execute on function public.create_ride_alert_sos(
  text,
  text,
  text,
  text,
  double precision,
  double precision,
  boolean
) to authenticated;

select exists (
  select 1
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'create_ride_alert_sos'
) as has_create_ride_alert_sos;
