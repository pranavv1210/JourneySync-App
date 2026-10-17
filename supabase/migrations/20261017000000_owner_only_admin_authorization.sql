-- Restrict JourneySync owner-dashboard access to the single verified owner
-- identity. The email requirement alone is not authoritative; the JWT must
-- also contain the server-managed app_metadata admin role.

begin;

create or replace function public.js_is_admin()
returns boolean
language sql
stable
security invoker
set search_path = pg_catalog
as $$
  select auth.uid() is not null
    and lower(coalesce(auth.jwt() ->> 'email', '')) =
      'journeysync.app@gmail.com'
    and lower(coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')) = 'admin'
$$;

revoke all on function public.js_is_admin() from public, anon;
grant execute on function public.js_is_admin() to authenticated;

commit;

-- Verification (read-only): exactly the intended helper definition should be
-- present, and existing policies should continue calling js_is_admin().
-- select pg_get_functiondef('public.js_is_admin()'::regprocedure);
-- select tablename, policyname, cmd, roles, qual
-- from pg_policies
-- where schemaname = 'public' and qual like '%js_is_admin%';
