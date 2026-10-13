-- JourneySync production migration-history normalization.
--
-- Run manually, as an authorized database operator, only after confirming the
-- five legacy versions below are the applied migrations shown by the Supabase
-- migration ledger. This is intentionally outside supabase/migrations so a
-- blocked `db push` cannot execute it speculatively.
--
-- This transaction changes migration metadata only. It does not modify the
-- application schema or application data.

begin;

do $repair$
declare
  old_count integer;
  new_count integer;
begin
  select count(*)
    into old_count
    from supabase_migrations.schema_migrations
   where version in (
     '20260306',
     '20260326',
     '20260415',
     '20260527',
     '20260621'
   );

  select count(*)
    into new_count
    from supabase_migrations.schema_migrations
   where version in (
     '20260306000000',
     '20260326000000',
     '20260415000000',
     '20260527000000',
     '20260621000000'
   );

  if old_count <> 5 or new_count <> 0 then
    raise exception
      'Migration ledger precondition failed (expected old=5/new=0, found old=%/new=%)',
      old_count,
      new_count;
  end if;

  update supabase_migrations.schema_migrations
     set version = case version
       when '20260306' then '20260306000000'
       when '20260326' then '20260326000000'
       when '20260415' then '20260415000000'
       when '20260527' then '20260527000000'
       when '20260621' then '20260621000000'
       else version
     end
   where version in (
     '20260306',
     '20260326',
     '20260415',
     '20260527',
     '20260621'
   );

  get diagnostics old_count = row_count;
  if old_count <> 5 then
    raise exception
      'Migration ledger update affected % rows instead of exactly 5',
      old_count;
  end if;

  select count(*)
    into new_count
    from supabase_migrations.schema_migrations
   where version in (
     '20260306000000',
     '20260326000000',
     '20260415000000',
     '20260527000000',
     '20260621000000'
   );

  if new_count <> 5 then
    raise exception
      'Migration ledger postcondition failed (expected 5 normalized rows, found %)',
      new_count;
  end if;
end
$repair$;

commit;

select version
  from supabase_migrations.schema_migrations
 where version in (
   '20260306000000',
   '20260326000000',
   '20260415000000',
   '20260527000000',
   '20260621000000'
 )
 order by version;
