-- MIGRATION: Remove the Jaap Counter feature (chant metadata)
--
-- The Jaap Counter feature was removed end-to-end: the Android app screens,
-- the admin panel section and the /api/admin/jaap-chants + /api/jaap-chants
-- routes are gone. This migration drops the admin-authored chant metadata
-- table that migrations 020-024 created. A user's counting data was always
-- device-local and is not present in this table.
--
-- Idempotent: safe for environments where 020-024 were never applied (e.g.
-- fresh databases created after the feature removal).

drop table if exists public.jaap_chants;