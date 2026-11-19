-- ============================================================
-- MIGRATION: the initial Top Trending pin set (the first 15 tracks)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- STATUS: ALREADY APPLIED to the production database (2026-11-18) through
-- POST /api/admin/trending/tracks, which calls the same function this file
-- calls. This file is the reproducible record of that change and an
-- idempotent way to restore it: running it again re-applies the identical
-- ranks and clears any pin outside this list.
--
-- REQUIRES 043_trending_order.sql. That migration adds tracks.trending_order
-- and the reorder_trending_tracks function this file calls.
--
-- What it does
--   Pins these 15 tracks as Top Trending ranks 1..15, in the order the
--   owner listed them. Everything not listed keeps the play-count
--   ranking and follows after rank 15.
--
--   It calls the same atomic function the admin "Arrange Top Trending"
--   panel calls, so the panel will show exactly this list afterwards and
--   the two can never disagree.
--
-- What it does NOT do
--   It does not touch tracks.featured_order, so Newest Arrivals is
--   unchanged. It does not delete or edit any track.
--
-- Safety
--   The call is a single atomic function invocation: it either applies the
--   whole list or nothing. Re-running this file is idempotent - it sets the
--   same ranks again and clears any pin outside this list.
--
-- The ids were resolved against the live catalogue by title; each line
-- carries its title so the order can be checked by eye.
-- ============================================================

begin;

select public.reorder_trending_tracks(array[
  '7517c3b2-329d-449c-95d1-efb3f473bdf3'::uuid,  --  1. Muddu Muddu Maatalatho
  '0ed33a4d-6073-4074-8059-5b3e4a533f0e'::uuid,  --  2. Gajaraja Vandana
  '83a327df-e6c4-43f1-99a3-d89603ee0ea1'::uuid,  --  3. Madhava Mukundha
  '8dbf1773-834b-47e0-989b-3da9281651a7'::uuid,  --  4. Krishna Anare
  'd5fa9263-ffd2-4a91-a561-4ad19bd647e1'::uuid,  --  5. Namo Sapthagiri
  '9fda23a5-f49b-4d6d-8580-0e50da490321'::uuid,  --  6. Srinivasa Kalyana Sambaram
  '6f8de1d3-a5f7-47df-bee3-601cd362860b'::uuid,  --  7. Durgammaa!
  'dcd9bdfd-435f-4ea7-9897-81799fe0de6c'::uuid,  --  8. Durgathi Nashini
  '7b9e98c9-552f-4c6f-b6a2-2c4b1096be9e'::uuid,  --  9. Kanaka Swaroopini
  '56e57058-671d-415c-b0b6-e48313f8459e'::uuid,  -- 10. Andala Hamsapai
  '07f2934c-77f7-45d7-aa77-53ce15c7bbb3'::uuid,  -- 11. Ramudu Vachadu Baala
  'b6811a3e-2005-4fd9-bb49-89b4f51e3aed'::uuid,  -- 12. Chintalu Maakela
  '307da6bf-bee1-41b2-94b0-bfafc2c86f2d'::uuid,  -- 13. Malle Maalalu
  '2bdf7163-f40a-4c6e-83cb-d5da2c101d76'::uuid,  -- 14. Rama Naamamu Madhuramu
  '72029c9c-9ed0-43c5-a0c0-f0744a98c61d'::uuid,  -- 15. Darshanamu Neeyara
]);

commit;

-- ------------------------------------------------------------------
-- Verify: expect exactly 15 rows, trending_order 1..15, no nulls, and the
-- titles in the requested order.
-- ------------------------------------------------------------------
select trending_order, title
from public.tracks
where trending_order is not null
order by trending_order;

-- ------------------------------------------------------------------
-- Verify (order check): expect 0 rows. Any row here means a stored pin does
-- not match the requested rank/title pair.
-- ------------------------------------------------------------------
with expected(rank, id, title) as (
  values
  (1, '7517c3b2-329d-449c-95d1-efb3f473bdf3'::uuid, 'Muddu Muddu Maatalatho'),
  (2, '0ed33a4d-6073-4074-8059-5b3e4a533f0e'::uuid, 'Gajaraja Vandana'),
  (3, '83a327df-e6c4-43f1-99a3-d89603ee0ea1'::uuid, 'Madhava Mukundha'),
  (4, '8dbf1773-834b-47e0-989b-3da9281651a7'::uuid, 'Krishna Anare'),
  (5, 'd5fa9263-ffd2-4a91-a561-4ad19bd647e1'::uuid, 'Namo Sapthagiri'),
  (6, '9fda23a5-f49b-4d6d-8580-0e50da490321'::uuid, 'Srinivasa Kalyana Sambaram'),
  (7, '6f8de1d3-a5f7-47df-bee3-601cd362860b'::uuid, 'Durgammaa!'),
  (8, 'dcd9bdfd-435f-4ea7-9897-81799fe0de6c'::uuid, 'Durgathi Nashini'),
  (9, '7b9e98c9-552f-4c6f-b6a2-2c4b1096be9e'::uuid, 'Kanaka Swaroopini'),
  (10, '56e57058-671d-415c-b0b6-e48313f8459e'::uuid, 'Andala Hamsapai'),
  (11, '07f2934c-77f7-45d7-aa77-53ce15c7bbb3'::uuid, 'Ramudu Vachadu Baala'),
  (12, 'b6811a3e-2005-4fd9-bb49-89b4f51e3aed'::uuid, 'Chintalu Maakela'),
  (13, '307da6bf-bee1-41b2-94b0-bfafc2c86f2d'::uuid, 'Malle Maalalu'),
  (14, '2bdf7163-f40a-4c6e-83cb-d5da2c101d76'::uuid, 'Rama Naamamu Madhuramu'),
  (15, '72029c9c-9ed0-43c5-a0c0-f0744a98c61d'::uuid, 'Darshanamu Neeyara')
)
select expected.rank, expected.title, tracks.title as stored_title, tracks.trending_order as stored_rank
from expected
left join public.tracks on tracks.id = expected.id
where tracks.id is null
   or tracks.trending_order is distinct from expected.rank
   or tracks.title is distinct from expected.title;

-- ------------------------------------------------------------------
-- Rollback (clears every pin, returning Top Trending to the play ranking)
--   select public.reorder_trending_tracks(array[]::uuid[]);
-- ------------------------------------------------------------------
