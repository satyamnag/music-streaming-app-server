-- ============================================================
-- MIGRATION: Track premium status (paid vs free)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
-- ============================================================

-- 1) Add the `status` column to the tracks table.
--    - default 'free' so existing tracks stay free
--    - CHECK constraint restricts values to 'free' or 'paid'
alter table tracks
  add column if not exists status text not null default 'free'
  check (status in ('free', 'paid'));

-- 2) Mark the two premium (paid) tracks.
--    Free users cannot play these without a subscription.
update tracks set status = 'paid'
where title in ('Sati Neku Yevaru', 'Edu Varike Vintha Vinta');

-- 3) Verify
select id, title, status from tracks order by created_at;
