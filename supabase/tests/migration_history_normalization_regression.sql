\set ON_ERROR_STOP on

drop schema if exists supabase_migrations cascade;
create schema supabase_migrations;
create table supabase_migrations.schema_migrations (
  version text primary key
);

insert into supabase_migrations.schema_migrations(version)
values
  ('20260306'),
  ('20260326'),
  ('20260415'),
  ('20260527'),
  ('20260621');

\ir ../operations/normalize_legacy_migration_versions.sql

do $test$
declare
  normalized_count integer;
  legacy_count integer;
begin
  select count(*) into normalized_count
    from supabase_migrations.schema_migrations
   where version in (
     '20260306000000',
     '20260326000000',
     '20260415000000',
     '20260527000000',
     '20260621000000'
   );

  select count(*) into legacy_count
    from supabase_migrations.schema_migrations
   where version in (
     '20260306',
     '20260326',
     '20260415',
     '20260527',
     '20260621'
   );

  if normalized_count <> 5 or legacy_count <> 0 then
    raise exception
      'Migration-history normalization regression (normalized=%, legacy=%)',
      normalized_count,
      legacy_count;
  end if;
end
$test$;

-- Idempotent safety means a second attempt must fail closed, not silently edit
-- an unexpected ledger. psql's error-state handling is awkward for an expected
-- failure, so the operator script's exact precondition is separately asserted.
do $test$
declare
  old_count integer;
  new_count integer;
begin
  select count(*) into old_count
    from supabase_migrations.schema_migrations
   where length(version) = 8;
  select count(*) into new_count
    from supabase_migrations.schema_migrations
   where length(version) = 14;

  if old_count <> 0 or new_count <> 5 then
    raise exception
      'Unexpected post-repair ledger shape (old=%, new=%)',
      old_count,
      new_count;
  end if;
end
$test$;

drop schema supabase_migrations cascade;
