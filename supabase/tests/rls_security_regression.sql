\set ON_ERROR_STOP on

create or replace function public.test_assert(ok boolean, message text)
returns void language plpgsql security invoker as $$
begin if not ok then raise exception 'SECURITY TEST FAILED: %', message; end if; end $$;
create or replace function public.test_expect_denied(statement text, message text)
returns void language plpgsql security invoker as $$
begin
  begin
    execute statement;
  exception when insufficient_privilege then return;
  end;
  raise exception 'SECURITY TEST FAILED: %', message;
end $$;
grant execute on function public.test_assert(boolean,text) to anon,authenticated;
grant execute on function public.test_expect_denied(text,text) to anon,authenticated;

-- Anonymous discovery is lifecycle-scoped; private data remains invisible.
set role anon;
select public.test_assert((select count(*) from ride_discovery)=1,'anonymous sees only sanitized active public rides');
select public.test_expect_denied('select * from rides','anonymous direct ride-table access');
select public.test_expect_denied('select * from live_locations','anonymous GPS access');
select public.test_expect_denied('select * from ride_members','anonymous membership access');
select public.test_expect_denied('select * from ride_routes','anonymous route access');
select public.test_expect_denied('select * from ride_alerts','anonymous SOS access');
select public.test_expect_denied('select * from ride_messages','anonymous chat access');
select public.test_expect_denied('select * from users','anonymous legacy user/GPS access');
select public.test_expect_denied('select * from participants','anonymous legacy membership access');
reset role;

-- Rider A can access Ride A but cannot cross into private Ride B.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',false);
select set_config('request.jwt.claims','{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}',false);
set role authenticated;
select public.test_assert((select count(*) from live_locations where ride_id='20000000-0000-0000-0000-0000000000a1')=1,'member reads own ride GPS');
select public.test_assert((select count(*) from live_locations where ride_id='20000000-0000-0000-0000-0000000000b2')=0,'cross-ride GPS isolation');
select public.test_assert((select count(*) from ride_routes where ride_id='20000000-0000-0000-0000-0000000000b2')=0,'cross-ride route isolation');
select public.test_assert((select count(*) from ride_alerts where ride_id='20000000-0000-0000-0000-0000000000b2')=0,'cross-ride SOS isolation');
select public.test_assert((select count(*) from ride_messages where ride_id='20000000-0000-0000-0000-0000000000b2')=0,'cross-ride chat isolation');
select public.test_assert((select count(*) from profiles where id='10000000-0000-0000-0000-000000000004')=0,'unrelated profile isolation');
select public.test_assert((select count(*) from profile_summaries where id='10000000-0000-0000-0000-000000000003')=0,'private host summary isolation');
insert into live_locations(ride_id,profile_id,latitude,longitude,is_leader)
values('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000002',12.1,77.1,false)
on conflict(ride_id,profile_id) do update set latitude=excluded.latitude,longitude=excluded.longitude;
select public.test_assert((select latitude from live_locations where profile_id='10000000-0000-0000-0000-000000000002')=12.1,'own GPS publish');

do $$ begin
  begin
    insert into live_locations(ride_id,profile_id,latitude,longitude,is_leader)
    values('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000004',1,1,false);
    raise exception 'spoofed GPS insert unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
end $$;
do $$ begin
  begin
    perform public.create_ride_alert_sos('20000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-000000000004','spoof','',1,1,false);
    raise exception 'spoofed SOS RPC unexpectedly succeeded';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- An unrelated rider can join public rides, but private rides require the
-- server-validated access code and never rely on a supplied profile id.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000006',false);
select set_config('request.jwt.claims','{"sub":"a0000000-0000-0000-0000-000000000006","role":"authenticated"}',false);
set role authenticated;
select public.test_assert(public.request_ride_join('20000000-0000-0000-0000-0000000000a1',null)='joined','public ride join');
select public.test_expect_denied($q$select public.request_ride_join('20000000-0000-0000-0000-0000000000b2',null)$q$,'private ride joined without code');
select public.test_assert((public.join_ride_by_access_code('JS-00B2')->>'status')='joined','private code join');
select public.test_assert((select count(*) from live_locations where ride_id='20000000-0000-0000-0000-0000000000b2')=1,'private member reads ride GPS');
reset role;

-- Pending riders are not participants.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000005',false);
select set_config('request.jwt.claims','{"sub":"a0000000-0000-0000-0000-000000000005","role":"authenticated"}',false);
set role authenticated;
select public.test_assert((select count(*) from live_locations)=0,'pending rider GPS access');
select public.test_assert((select count(*) from ride_messages)=0,'pending rider chat access');
select public.test_assert((select count(*) from ride_members)=1,'pending rider sees only own membership request');
reset role;

-- Host A can see and manage its own membership, never Ride B.
select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',false);
select set_config('request.jwt.claims','{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}',false);
set role authenticated;
select public.test_assert((select count(*) from ride_members where ride_id='20000000-0000-0000-0000-0000000000a1')=3,'host membership visibility');
select public.test_assert((select count(*) from ride_members where ride_id='20000000-0000-0000-0000-0000000000b2')=0,'cross-host membership isolation');
update ride_members set status='approved' where id='30000000-0000-0000-0000-000000000002';
select public.test_assert((select status from ride_members where id='30000000-0000-0000-0000-000000000002')='approved','host approval');
select public.test_expect_denied($q$update ride_members set role='host' where id='30000000-0000-0000-0000-000000000002'$q$,'host elevated another membership role');
reset role;

drop function public.test_assert(boolean,text);
drop function public.test_expect_denied(text,text);
