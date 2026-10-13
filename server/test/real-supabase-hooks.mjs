// ESM loader hook: swaps @supabase/supabase-js for the real-PostgreSQL adapter
// so server.js can be exercised against a genuine database.

import { pathToFileURL } from 'node:url'
import path from 'node:path'

const ADAPTER_URL = pathToFileURL(
  path.join(import.meta.dirname, 'real-supabase-adapter.mjs'),
).href

export async function resolve(specifier, context, nextResolve) {
  if (specifier === '@supabase/supabase-js' || specifier.startsWith('@supabase/supabase-js/')) {
    return { url: ADAPTER_URL, shortCircuit: true, format: 'module' }
  }
  return nextResolve(specifier, context)
}
