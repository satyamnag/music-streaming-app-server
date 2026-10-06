// Tests for the featured-playlist payload validator and its title requirement.
//
// A PUT to /api/admin/featured-playlists/:id is an upsert: it either creates a
// chip or edits an existing one. Only CREATION needs a title — an existing chip
// is edited field-by-field, and the icon upload / remove-icon paths in the
// admin panel send `icon_url` alone. Requiring a title on every payload made
// those uploads fail with "title is required". These tests pin down the
// requireTitle boundary so that regression cannot come back.
//
// The function lives in server.js, which starts an HTTP server when imported, so
// it is extracted by matching braces — the same approach as
// missing_column_error.test.mjs. The colour fields are deliberately not
// exercised here: they call cleanHexColor, which is not in the extracted scope.
//
// Run: node --test server/test/featured_payload.test.mjs

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

  // Walk the parameter list to its closing ')' — parameters may carry braces
  // (e.g. { requireTitle = true } = {}), which would fool a brace counter that
  // starts at the first '{' after the name.
  let i = match.index + match[0].length
  let parenDepth = 1
  let inString = null
  for (; i < source.length; i++) {
    const ch = source[i]
    if (inString) {
      if (ch === '\\') i++
      else if (ch === inString) inString = null
      continue
    }
    if (ch === '"' || ch === "'" || ch === '`') inString = ch
    else if (ch === '(') parenDepth++
    else if (ch === ')' && --parenDepth === 0) break
  }

  // The body brace after the closing ')', then plain brace matching from there.
  // The slice starts at the `function` keyword so the synthesized script holds a
  // real function declaration (the braces walked are only used to find its end).
  const bodyStart = source.indexOf('{', i)
  let depth = 0
  for (let j = bodyStart; j < source.length; j++) {
    if (source[j] === '{') depth++
    else if (source[j] === '}' && --depth === 0) {
      // eslint-disable-next-line no-new-func
      return new Function(`${source.slice(match.index, j + 1)}\nreturn ${name};`)()
    }
  }
  throw new Error(`unbalanced braces after ${name}`)
}

const readFeaturedPlaylistPayload = loadFunction(
  readFileSync(SERVER_JS, 'utf8'),
  'readFeaturedPlaylistPayload',
)

test('an icon-only payload is rejected when the row would be CREATED', () => {
  // Creation without a name must still fail loudly (fail-closed default).
  const result = readFeaturedPlaylistPayload({ icon_url: 'https://cdn/x.webp' })
  assert.equal(result.error, 'title is required')
  assert.equal(result.row, undefined)
})

test('an icon-only payload is accepted when the row already EXISTS', () => {
  const result = readFeaturedPlaylistPayload({ icon_url: 'https://cdn/x.webp' }, { requireTitle: false })
  assert.equal(result.error, undefined)
  assert.deepEqual(result.row, { icon_url: 'https://cdn/x.webp' })
})

test('removing the icon (icon_url: null) is a valid partial update', () => {
  const result = readFeaturedPlaylistPayload({ icon_url: null }, { requireTitle: false })
  assert.equal(result.error, undefined)
  assert.deepEqual(result.row, { icon_url: null })
})

test('an empty payload is a valid partial update (route guards "nothing to update")', () => {
  const result = readFeaturedPlaylistPayload({}, { requireTitle: false })
  assert.equal(result.error, undefined)
  assert.deepEqual(result.row, {})
})

test('a present-but-blank title is still rejected on an update', () => {
  const result = readFeaturedPlaylistPayload({ title: '   ' }, { requireTitle: false })
  assert.equal(result.error, 'title must be a non-empty string')
})

test('title and icon_url survive a partial update together', () => {
  const result = readFeaturedPlaylistPayload(
    { title: '  Bhajans  ', icon_url: 'https://cdn/x.webp' },
    { requireTitle: false },
  )
  assert.equal(result.error, undefined)
  assert.deepEqual(result.row, { title: 'Bhajans', icon_url: 'https://cdn/x.webp' })
})