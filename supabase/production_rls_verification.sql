-- Read-only production verification. Run before and after the migration and
-- retain the output in the incident record. This returns metadata, never rider rows.

select n.nspname as schemaname,c.relname as tablename,
       c.relrowsecurity as rowsecurity,c.relforcerowsecurity as forcerowsecurity
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname in ('public','storage') and c.relkind='r'
  and c.relname in (
    'profiles','users','rides','participants','ride_members','live_locations','ride_routes','ride_alerts',
    'ride_messages','notifications','ride_summaries','user_device_sessions',
    'objects'
  )
order by n.nspname,c.relname;

select schemaname,tablename,policyname,permissive,roles,cmd,qual,with_check
from pg_policies
where (schemaname='public' and tablename in (
    'profiles','users','rides','participants','ride_members','live_locations','ride_routes','ride_alerts',
    'ride_messages','notifications','ride_summaries','user_device_sessions'
  )) or (schemaname='storage' and tablename='objects')
order by schemaname,tablename,policyname;

select table_schema,table_name,grantee,privilege_type
from information_schema.role_table_grants
where table_schema in ('public','storage')
  and grantee in ('anon','authenticated','public')
order by table_schema,table_name,grantee,privilege_type;

select n.nspname as schema_name,p.proname,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       pg_get_userbyid(p.proowner) as owner,
       p.proconfig as settings,
       p.proacl as acl
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'current_profile_id_text','is_ride_participant_text','is_ride_host_text',
    'profile_is_ride_participant_text','profile_is_ride_host_text',
    'create_ride_alert_sos','request_ride_join','join_ride_by_access_code',
    'js_current_profile_id','js_is_ride_participant','js_is_ride_host'
  )
order by p.proname,arguments;

select pubname,schemaname,tablename
from pg_publication_tables
where pubname='supabase_realtime'
order by schemaname,tablename;

select version from supabase_migrations.schema_migrations
order by version;
