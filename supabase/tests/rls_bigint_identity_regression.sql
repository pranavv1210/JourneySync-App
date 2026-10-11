\set ON_ERROR_STOP on
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',false);
select set_config('request.jwt.claims','{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}',false);
set role authenticated;
select public.request_ride_join('20000000-0000-0000-0000-0000000000a1',null);
do $$ begin
  if not exists(select 1 from public.ride_members where member_id=102 and status='approved') then
    raise exception 'bigint profile could not join ride';
  end if;
end $$;
select public.create_ride_alert_sos(
  '20000000-0000-0000-0000-0000000000a1','102','Rider','',12,77,false
);
do $$ begin
  if not exists(select 1 from public.ride_alerts where profile_id=102 and type='sos') then
    raise exception 'bigint profile could not create SOS';
  end if;
end $$;
reset role;
