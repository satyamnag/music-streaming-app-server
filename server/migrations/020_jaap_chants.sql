-- ============================================================
-- MIGRATION: Jaap chant metadata
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Purpose:
--   Lets an ADMIN define the canonical metadata for a jaap: its name and the
--   exact text of the chant. These are shared definitions, authored in the web
--   admin panel and readable by the app.
--
--   Only admins may write: the server's /api/admin/jaap-chants endpoints are
--   all behind requireAdmin, and the RLS policy below grants SELECT only to
--   the public API roles. Writes happen with the service_role key, which
--   bypasses RLS.
--
-- Scope:
--   This is metadata only. A user's counting (counters, daily totals, streaks)
--   stays on-device and is NOT stored here.
--
-- Additive and safe - no existing table is touched.
-- ============================================================

create table if not exists public.jaap_chants (
  id uuid primary key default gen_random_uuid(),
  name text not null,                       -- the jaap name, e.g. "Gayatri Mantra"
  chant_text text not null,                 -- the exact text of the chant
  default_target integer not null default 108,
  sort_order integer not null default 0,
  status text not null default 'free' check (status in ('free', 'paid')),
  created_at timestamptz not null default now(),
  -- The exact text must never be blank: an empty chant would be unusable and
  -- is almost certainly an accidental edit.
  constraint jaap_chants_name_not_blank check (length(btrim(name)) > 0),
  constraint jaap_chants_text_not_blank check (length(btrim(chant_text)) > 0),
  constraint jaap_chants_target_positive check (default_target > 0)
);

alter table public.jaap_chants enable row level security;

-- Chants are publicly readable, matching the albums table, so the app can read
-- them through the anon key. There is deliberately NO insert/update/delete
-- policy: those require the service_role key used by the admin panel.
drop policy if exists "Jaap chants are publicly readable" on public.jaap_chants;
create policy "Jaap chants are publicly readable"
  on public.jaap_chants
  for select
  using (true);

create index if not exists jaap_chants_sort_idx
  on public.jaap_chants (sort_order asc, created_at desc);

-- ------------------------------------------------------------------
-- Verify (expect the 7 columns below)
-- ------------------------------------------------------------------
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'jaap_chants'
order by ordinal_position;
