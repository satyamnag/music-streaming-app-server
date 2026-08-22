-- ============================================================
-- MIGRATION: Track TAGS (admin web interface)
-- Run this in the Supabase SQL Editor (Dashboard > SQL Editor) once.
--
-- Stores comma-separated tags per track (e.g. "bhajan, devotional,
-- morning"). The admin portal lets the admin add/edit tags and search
-- tracks by tag. The Android app does not use this column yet.
-- ============================================================

alter table tracks add column if not exists tags text;