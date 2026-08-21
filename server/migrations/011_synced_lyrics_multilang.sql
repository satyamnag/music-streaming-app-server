-- Add multi-language synced-lyrics columns (English & Hindi) for the admin
-- "Add Sync Lyrics" editor.
--
-- The Flutter client only consumes `synced_lyrics` (the main/Telugu LRC), so
-- these two columns are ignored by the app and this change is non-breaking.
-- Run in the Supabase SQL Editor (or psql) once before using the feature.

alter table tracks add column if not exists synced_lyrics_en text;
alter table tracks add column if not exists synced_lyrics_hi text;
