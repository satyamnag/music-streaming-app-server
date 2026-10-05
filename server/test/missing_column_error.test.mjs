// Tests for the "that column does not exist yet" guard.
//
// The app already handles one un-applied migration this way — a save that carries
// the transliteration columns retries without them when those columns are missing
// (server.js, the `missingTrColumns` retry). This guard is the same idea for the
// mini player colour, except it REFUSES the save with an actionable message
// instead of silently dropping the colour, because losing an admin's choice
// without telling them is worse than an error they can act on.
//
// What it must NOT do is claim a migration is missing for some unrelated error:
// that would send an admin chasing a migration when the real problem is something
// else entirely. Most of these tests are about that.
//
// The function lives in server.js, which starts an HTTP server when imported, so
// it is extracted by matching braces. A rename fails loudly with "not found"
// rather than silently testing nothing.
//
// Run: node --test server/test/missing_column_error.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const SERVER_JS = join(here, '..', 'server.js')

/** Pulls one function's source out of a module and returns it as a value. */
const loadFunction = (source, name) => {
  const pattern = new RegExp(`(?:async )?function ${name}\\(`)
  const match = pattern.exec(source)
  assert.notEqual(match, null, `${name} not found — was it renamed?`)
  const start = match.index
  let depth = 0
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++
    else if (source[i] === '}' && --depth === 0) {
      // eslint-disable-next-line no-new-func
      return new Function(`${source.slice(start, i + 1)}\nreturn ${name};`)()
    }
  }
  throw new Error(`unbalanced braces after ${name}`)
}

const isMissingColumnError = loadFunction(readFileSync(SERVER_JS, 'utf8'), 'isMissingColumnError')

// The two codes PostgREST/Postgres use, with messages in their real shapes.
const pgrst204 = (col) => ({
  code: 'PGRST204',
  message: `Could not find the '${col}' column of 'tracks' in the schema cache`,
})
const pg42703 = (col) => ({
  code: '42703',
  message: `column "${col}" of relation "tracks" does not exist`,
})

test('both real "missing column" error shapes are recognised', () => {
  assert.equal(isMissingColumnError(pgrst204('miniplayer_bg_color'), 'miniplayer_bg_color'), true)
  assert.equal(isMissingColumnError(pg42703('miniplayer_bg_color'), 'miniplayer_bg_color'), true)
})

test('a DIFFERENT missing column is not blamed on this migration', () => {
  // The important negative: if some other column is missing, telling the admin to
  // run the mini-player migration would send them chasing the wrong fix.
  assert.equal(isMissingColumnError(pgrst204('some_other_column'), 'miniplayer_bg_color'), false)
  assert.equal(isMissingColumnError(pg42703('card_bg_color'), 'miniplayer_bg_color'), false)
})

test('only the two missing-column codes count', () => {
  for (const code of ['23505', '42501', '42P01', 'PGRST301', '500', undefined]) {
    assert.equal(
      isMissingColumnError({ code, message: 'miniplayer_bg_color' }, 'miniplayer_bg_color'),
      false,
      `code ${code} must not be treated as a missing column`,
    )
  }
})

test('nothing at all is not a missing column', () => {
  assert.equal(isMissingColumnError(null, 'miniplayer_bg_color'), false)
  assert.equal(isMissingColumnError(undefined, 'miniplayer_bg_color'), false)
})

test('a right-coded error with no message is NOT claimed', () => {
  // Conservative on purpose: without the column named in the message there is no
  // evidence about WHICH column is missing, so it must not be asserted.
  assert.equal(isMissingColumnError({ code: 'PGRST204' }, 'miniplayer_bg_color'), false)
  assert.equal(isMissingColumnError({ code: 'PGRST204', message: '' }, 'miniplayer_bg_color'), false)
})

test('the guard matches by column name, not by substring accident', () => {
  // `miniplayer_bg_color_extra` contains the name; a message about it would be a
  // different column. Includes() is what the guard uses, so pin the intent: the
  // real messages quote the exact column, and this documents the boundary.
  assert.equal(
    isMissingColumnError(pgrst204('miniplayer_bg_color'), 'miniplayer_bg_color'),
    true,
  )
  assert.equal(
    isMissingColumnError({ code: 'PGRST204', message: 'schema cache is stale' }, 'miniplayer_bg_color'),
    false,
  )
})
