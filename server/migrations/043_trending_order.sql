-- ============================================================
-- MIGRATION: Trending ordering for tracks
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor).
--
-- Purpose
--   Lets the admin arrange the Top Trending list (admin -> "Arrange
--   Top Trending") the same way "Arrange Albums" arranges albums.
--   Without this, Top Trending is purely the play-count ranking.
--
-- What it changes, and what it does not
--   Top Trending is normally ranked by how often each song has been
--   played. This adds a CURATED PREFIX: every track the admin pins
--   carries a non-null `trending_order`, and the readers show those
--   first in that order, then the play-count ranking for everything
--   else. An empty list (every trending_order null) is exactly the
--   behaviour before this migration, so the feature is inert until
--   the admin uses it.
--
--   It deliberately does NOT touch `featured_order`, which drives
--   Newest Arrivals. The two orders are independent: pinning a song
--   as trending must not move it in Newest Arrivals, and vice versa.
--
-- Scalability (10000+ tracks)
--   Only the pinned subset carries a non-null `trending_order`, and
--   reordering only ever touches that small subset inside one atomic
--   function, so arranging stays fast and cheap at any catalog size.
--
-- Ordering rule used everywhere
--   ORDER BY trending_order ASC NULLS LAST, then the play-count
--   ranking, then the track name as a stable tie-break.
-- ============================================================

-- ------------------------------------------------------------------
-- 1) Column + partial index (only the pinned subset is indexed)
-- ------------------------------------------------------------------
alter table public.tracks
  add column if not exists trending_order integer;

create index if not exists tracks_trending_order_idx
  on public.tracks (trending_order)
  where trending_order is not null;

-- ------------------------------------------------------------------
-- 2) Atomic reorder helper
--
-- Takes the COMPLETE desired pinned id list, in order:
--   * sets trending_order = 1..n for those ids,
--   * clears trending_order (null) for any previously-pinned row
--     that is NOT in the list.
-- Empty array => clear every pin (back to the play ranking).
--
-- SECURITY INVOKER + service-role caller (the admin server) => RLS
-- bypass, and no grant is needed for anon/authenticated, which never
-- call this.
-- ------------------------------------------------------------------
create or replace function public.reorder_trending_tracks(p_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.tracks
    set trending_order = null
    where trending_order is not null
      and not (id = any(p_ids));

  update public.tracks t
    set trending_order = s.ord
    from unnest(p_ids) with ordinality as s(id, ord)
    where t.id = s.id;
end;
$$;

-- ------------------------------------------------------------------
-- 3) Verify
--   Expect one row (trending_order), one row (the index) and one row
--   (the function).
-- ------------------------------------------------------------------
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'tracks' and column_name = 'trending_order';

select indexname from pg_indexes
where schemaname = 'public' and tablename = 'tracks' and indexname = 'tracks_trending_order_idx';

select proname from pg_proc
where proname = 'reorder_trending_tracks';

-- ------------------------------------------------------------------
-- 4) Rollback (only if this feature is ever withdrawn)
--   drop function if exists public.reorder_trending_tracks(uuid[]);
--   drop index if exists public.tracks_trending_order_idx;
--   alter table public.tracks drop column if exists trending_order;
-- ------------------------------------------------------------------
