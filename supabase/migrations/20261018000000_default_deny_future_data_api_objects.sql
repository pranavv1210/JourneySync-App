-- Adopt Supabase's October 30, 2026 Data API default-privilege behavior now.
-- This affects only objects created after this migration. Existing tables,
-- functions, grants, policies, and application data are unchanged.

begin;

alter default privileges for role postgres in schema public
  revoke select, insert, update, delete on tables
  from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke usage, select, update on sequences
  from anon, authenticated, service_role;

-- PostgreSQL grants EXECUTE on new functions to PUBLIC by default. Requiring
-- an explicit grant keeps future RPC endpoints private until reviewed.
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated, service_role;

commit;

-- Read-only production verification:
-- select defaclobjtype, defaclacl
-- from pg_default_acl
-- where defaclnamespace = 'public'::regnamespace
--   and defaclrole = 'postgres'::regrole
-- order by defaclobjtype;
