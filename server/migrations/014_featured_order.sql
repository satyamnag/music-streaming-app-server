-- ============================================================
-- MIGRATION: Featured ordering for tracks and albums
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Purpose
--   Lets the admin arrange songs and albums so specific items are
--   shown first on the home screen ("first few songs", "first few
--   albums").
--
-- Scalability (10000+ tracks)
--   Only the items the admin explicitly features carry a non-null
--   `featured_order`. Reordering only ever touches that small
--   featured subset (atomic RPC), never the full catalog, so the
--   feature stays fast and cheap at any catalog size.
--
-- Ordering rule used everywhere
--   ORDER BY featured_order ASC NULLS LAST, then the existing
--   natural order (created_at) for everything not featured.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Columns
-- ------------------------------------------------------------------
alter table public.tracks
  add column if not exists featured_order integer;

alter table public.albums
  add column if not exists featured_order integer;

-- Partial indexes: only the (small) featured subset is indexed.
create index if not exists tracks_featured_order_idx
  on public.tracks (featured_order)
  where featured_order is not null;

create index if not exists albums_featured_order_idx
  on public.albums (featured_order)
  where featured_order is not null;

-- ------------------------------------------------------------------
-- 2) Atomic reorder helpers
--
-- Each call takes the COMPLETE desired featured id list, in order:
--   * sets featured_order = 1..n for those ids,
--   * clears featured_order (null) for any previously-featured row
--     that is NOT in the list.
-- Empty array => unfeature everything.
-- SECURITY INVOKER + service-role caller (admin server) -> RLS bypass,
-- no grants needed for anon/authenticated (they never call these).
-- ------------------------------------------------------------------
create or replace function public.reorder_featured_tracks(p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.tracks
    set featured_order = null
    where featured_order is not null
      and not (id = any(p_ids));

  update public.tracks t
    set featured_order = s.ord
    from unnest(p_ids) with ordinality as s(id, ord)
    where t.id = s.id;
end;
$$;

create or replace function public.reorder_featured_albums(p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.albums
    set featured_order = null
    where featured_order is not null
      and not (id = any(p_ids));

  update public.albums a
    set featured_order = s.ord
    from unnest(p_ids) with ordinality as s(id, ord)
    where a.id = s.id;
end;
$$;

-- ------------------------------------------------------------------
-- Verify
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema='public' and table_name='tracks' and column_name='featured_order';

select column_name from information_schema.columns
where table_schema='public' and table_name='albums' and column_name='featured_order';

select proname from pg_proc
where proname in ('reorder_featured_tracks', 'reorder_featured_albums');