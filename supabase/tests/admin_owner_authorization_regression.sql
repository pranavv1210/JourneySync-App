\set ON_ERROR_STOP on

reset role;
create or replace function public.test_assert(ok boolean, message text)
returns void language plpgsql security invoker as $$
begin if not ok then raise exception 'SECURITY TEST FAILED: %', message; end if; end $$;
grant execute on function public.test_assert(boolean,text) to authenticated;

set role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","email":"attacker@example.com","role":"authenticated","app_metadata":{"role":"admin"}}',
  false
);
select public.test_assert(not public.js_is_admin(), 'admin role with another email is denied');

select set_config(
  'request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","email":"journeysync.app@gmail.com","role":"authenticated","app_metadata":{"role":"member"}}',
  false
);
select public.test_assert(not public.js_is_admin(), 'owner email without server admin role is denied');

select set_config(
  'request.jwt.claims',
  '{"sub":"a0000000-0000-0000-0000-000000000001","email":"journeysync.app@gmail.com","role":"authenticated","app_metadata":{"role":"admin"}}',
  false
);
select public.test_assert(public.js_is_admin(), 'verified owner identity is allowed');

reset role;
