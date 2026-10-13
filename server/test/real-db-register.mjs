// ============================================================================
// REGISTER-BASED HARNESS: runs server.js against a REAL PostgreSQL database
// ============================================================================
//
// `register()` installs an ESM resolve hook that swaps @supabase/supabase-js
// for the real-Postgres adapter, then imports server.js in this same process.
//
// Usage (from server/):
//   node test/real-db-register.mjs test/partner-real-db.test.mjs
//
// Requires env:
//   PARTNER_TEST_DB_URL  e.g. postgres://postgres:testpw@127.0.0.1:55432/sb_partner_test
//   PG_BIN               directory holding psql.exe (optional; only for setup)

import { register } from 'node:module'
import { pathToFileURL } from 'node:url'
import path from 'node:path'

register(
  pathToFileURL(path.join(import.meta.dirname, 'real-supabase-hooks.mjs')).href,
)

const target = process.argv[2] || path.join(import.meta.dirname, 'partner-real-db.test.mjs')
await import(pathToFileURL(path.resolve(target)).href)
