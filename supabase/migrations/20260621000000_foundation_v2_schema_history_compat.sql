-- Migration-history compatibility marker.
--
-- Production already records the original 20260621 foundation migration.
-- A Supabase preview run briefly recorded the normalized 20260621000000
-- identifier before that production version was restored in the repository.
-- Keep both identifiers available without applying the foundation schema twice.

select 1;
