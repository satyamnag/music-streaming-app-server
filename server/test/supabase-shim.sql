-- ============================================================================
-- Local test shim: emulate the Supabase platform primitives
-- ============================================================================
-- The migrations in this repo assume a Supabase Postgres instance, which
-- provides things vanilla PostgreSQL does not:
--
--   * the `auth` schema, with an `auth.uid()` function reading the request JWT
--   * the roles `anon`, `authenticated`, `service_role`
--   * the `storage` schema, with `storage.buckets` and `storage.objects`
--   * `vault.decrypted_secrets`
--
-- This file recreates the MINIMUM of those so the real migrations can be
-- applied and exercised against a genuine PostgreSQL server. It is a TEST
-- FIXTURE: it is never applied in production and does not ship.
--
-- The goal is to test the migrations' own logic (constraints, functions,
-- grants, RLS posture) rather than to reimplement Supabase.
-- ============================================================================

-- --- roles ------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end $$;

-- --- auth schema + auth.uid() -----------------------------------------------
create schema if not exists auth;

-- Mirrors Supabase's auth.uid(): returns the `sub` claim of the request JWT.
-- Locally there is no PostgREST request context, so it returns NULL unless a
-- test sets `request.jwt.claims`. That NULL behaviour is exactly what RLS
-- policies in this repo are designed around, so it is faithful enough.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    coalesce(
      current_setting('request.jwt.claim.sub', true),
      (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
    ),
    ''
  )::uuid;
$$;

-- Supabase also exposes auth.role() and auth.jwt().
create or replace function auth.role()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'),
    'anon'
  );
$$;

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb);
$$;

-- --- storage schema ---------------------------------------------------------
create schema if not exists storage;

create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  owner uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  public boolean default false,
  avif_autodetection boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  owner_id text
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text,
  owner uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  last_accessed_at timestamptz default now(),
  metadata jsonb,
  path_tokens text[] generated always as (string_to_array(name, '/')) stored,
  version text,
  owner_id text,
  user_metadata jsonb
);

alter table storage.objects enable row level security;
alter table storage.buckets enable row level security;

-- Supabase helper functions used when authoring storage policies.
create or replace function storage.foldername(name text)
returns text[]
language plpgsql
immutable
as $$
declare
  parts text[];
begin
  parts := string_to_array(name, '/');
  return parts[1:array_length(parts, 1) - 1];
end;
$$;

create or replace function storage.filename(name text)
returns text
language plpgsql
immutable
as $$
declare
  parts text[];
begin
  parts := string_to_array(name, '/');
  return parts[array_length(parts, 1)];
end;
$$;

create or replace function storage.extension(name text)
returns text
language plpgsql
immutable
as $$
declare
  parts text[];
begin
  parts := string_to_array(name, '.');
  return parts[array_length(parts, 1)];
end;
$$;

-- --- vault schema -----------------------------------------------------------
create schema if not exists vault;

create table if not exists vault.secrets (
  id uuid primary key default gen_random_uuid(),
  name text unique,
  description text,
  secret text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Supabase exposes a decrypted view restricted to service_role.
create or replace view vault.decrypted_secrets as
  select id, name, description, secret as decrypted_secret, created_at, updated_at
  from vault.secrets;

-- --- grants mirroring Supabase ---------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema storage to anon, authenticated, service_role;
grant usage on schema vault to service_role;
grant all on all tables in schema public to service_role;
grant all on all tables in schema storage to service_role;

-- Confirm the shim is in place.
do $$
begin
  raise notice 'Supabase test shim installed: roles, auth, storage, vault';
end $$;
