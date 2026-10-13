// Entry script that installs the Supabase stub loader hook, then runs the
// integration test in the same process.
//
// Why this exists: ESM loader hooks exported from a module loaded via
// `--import` are not reliably applied to the importing process's own later
// imports. `module.register()` is the documented way to install hooks that
// take effect for subsequent resolution in this process.
//
// Usage:  node test/partner-stub-register.mjs test/partner-flow.test.mjs

import { register } from 'node:module'
import { pathToFileURL } from 'node:url'
import path from 'node:path'

register(
  pathToFileURL(path.join(import.meta.dirname, 'partner-stub-hooks.mjs')).href,
)

const target = process.argv[2] || path.join(import.meta.dirname, 'partner-flow.test.mjs')
await import(pathToFileURL(path.resolve(target)).href)
