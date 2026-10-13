// ESM loader hooks: replaces @supabase/supabase-js with the in-memory stub so
// server.js can be booted for integration tests without a live Supabase.
//
// Register with:
//   node --import ./test/partner-stub-register.mjs test/partner-flow.test.mjs
//
// NOTE: hooks exported from a module passed to `--import` are NOT applied to
// that same process's later dynamic imports in all Node versions — the
// documented, reliable mechanism is `module.register(specifier)` from a small
// entry script (partner-stub-register.mjs), which is what we do.

import { pathToFileURL } from 'node:url'
import path from 'node:path'

const STUB_URL = pathToFileURL(
  path.join(import.meta.dirname, 'supabase-stub.mjs'),
).href

export async function resolve(specifier, context, nextResolve) {
  // Match the bare specifier and any subpath of the package.
  if (specifier === '@supabase/supabase-js' || specifier.startsWith('@supabase/supabase-js/')) {
    return { url: STUB_URL, shortCircuit: true, format: 'module' }
  }
  return nextResolve(specifier, context)
}
