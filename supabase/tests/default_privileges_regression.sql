\set ON_ERROR_STOP on

reset role;

create table public.default_privileges_probe (
  id bigint generated always as identity primary key
);

do $$
declare
  sequence_name text;
  role_name text;
begin
  foreach role_name in array array['anon', 'authenticated', 'service_role'] loop
    if has_table_privilege(role_name, 'public.default_privileges_probe', 'select')
       or has_table_privilege(role_name, 'public.default_privileges_probe', 'insert')
       or has_table_privilege(role_name, 'public.default_privileges_probe', 'update')
       or has_table_privilege(role_name, 'public.default_privileges_probe', 'delete') then
      raise exception 'SECURITY TEST FAILED: % inherited table privileges', role_name;
    end if;
  end loop;

  select pg_get_serial_sequence(
    'public.default_privileges_probe',
    'id'
  ) into sequence_name;

  foreach role_name in array array['anon', 'authenticated', 'service_role'] loop
    if has_sequence_privilege(role_name, sequence_name, 'usage')
       or has_sequence_privilege(role_name, sequence_name, 'select')
       or has_sequence_privilege(role_name, sequence_name, 'update') then
      raise exception 'SECURITY TEST FAILED: % inherited sequence privileges', role_name;
    end if;
  end loop;
end $$;

drop table public.default_privileges_probe;
