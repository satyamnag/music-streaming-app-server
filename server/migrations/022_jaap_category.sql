-- ============================================================
-- MIGRATION: Jaap chant category (mantra | stotra)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Adds `category` to public.jaap_chants so the Japa page can show the curated
-- chants in two collections: "Mantra Japa" and "Stotra Japa". Existing rows
-- default to 'mantra'. Fully additive — nothing else changes.
-- ============================================================

alter table public.jaap_chants
  add column if not exists category text not null default 'mantra'
    check (category in ('mantra', 'stotra'));

comment on column public.jaap_chants.category is
  'Which Japa section the chant appears in: mantra (invocation) or stotra (hymn).';

-- ------------------------------------------------------------------
-- Verify (expect one row: category)
-- ------------------------------------------------------------------
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'jaap_chants' and column_name = 'category';