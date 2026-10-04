-- ============================================================
-- MIGRATION: Landscape banners for the Specials carousel
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- Adds a `banner_url` column to `specials` (the curated home shelves such as
-- "Ganesha Special"), holding the public URL of an admin-uploaded LANDSCAPE
-- banner image.
--
-- The banner is STRICTLY WebP at 8:3 (2.667:1), enforced by the server on
-- upload so the rule cannot be bypassed by calling the API directly. When a
-- special has no banner, the app falls back to the shelf's track artwork.
--
-- This also creates the `specials` table itself when it does not exist, so the
-- feature works on a project where the shelves have only been derived from
-- track keywords until now. Rows are optional: a special with no row simply
-- uses its built-in default title/subtitle/keywords and no banner.
--
-- Additive and safe: the column is nullable with no default, and every reader
-- falls back to the previous behaviour.
-- ============================================================

create table if not exists public.specials (
    id           text primary key,
    title        text,
    subtitle     text,
    sort_order   integer,
    banner_url   text,
    is_hidden    boolean not null default false,
    created_at   timestamp with time zone default now(),
    updated_at   timestamp with time zone default now()
);

-- Additive on an existing table (the table above may already exist without the
-- banner columns).
alter table public.specials
  add column if not exists banner_url  text,
  add column if not exists sort_order  integer,
  add column if not exists is_hidden   boolean not null default false,
  add column if not exists updated_at  timestamp with time zone default now();

-- Public read: the home screen needs these without a session.
alter table public.specials enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'specials'
      and policyname = 'Specials are publicly readable'
  ) then
    create policy "Specials are publicly readable"
      on public.specials for select using (true);
  end if;
end $$;

-- Only the admin (service role, which bypasses RLS) writes to this table, so no
-- insert/update/delete policy is granted to anon or authenticated.

-- ------------------------------------------------------------------
-- Verify: expect the specials table with a banner_url column.
-- ------------------------------------------------------------------
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'specials'
order by ordinal_position;
