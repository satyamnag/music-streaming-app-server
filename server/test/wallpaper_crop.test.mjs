// Tests for the wallpaper centre-crop that the admin applies on upload.
//
// Why this is tested by EXTRACTION rather than import: the function lives inside
// `server/admin.html`, a static page served to the browser — it is not a module
// the server can import, so running the real code means pulling it out of the
// page. The extraction is deliberately brittle in the SAFE direction: if the
// function is renamed or removed, the test fails immediately with "not found"
// rather than silently testing nothing.
//
// It matters because this function decides what every uploaded wallpaper is
// stored as, and its failure mode is SILENT — every error path falls back to
// uploading the original file, so a broken crop looks like "the trim does
// nothing" rather than an error anyone would notice.
//
// Run: node --test server/test/wallpaper_crop.test.mjs

import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
const ADMIN_HTML = join(here, '..', 'admin.html')

/** The band's aspect ratio, kept in step with the page's own constant. */
const TARGET_RATIO = 8 / 3

/** Pulls one function's full source out of the page by matching its braces. */
const extractFunction = (source, name) => {
  const start = source.indexOf(`async function ${name}(`)
  assert.notEqual(start, -1, `${name} not found in admin.html — was it renamed?`)
  let depth = 0
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++
    else if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1)
  }
  throw new Error(`unbalanced braces after ${name}`)
}

/** A stand-in for the browser File the page builds. */
class FakeFile {
  constructor(parts, name, opts) {
    this.parts = parts
    this.name = name
    this.type = opts?.type ?? ''
  }
}

/**
 * Runs the real `normaliseWallpaper` against a stubbed canvas and reports the one
 * crop it asked for, the canvas it produced, and whether it handed back the
 * original file untouched.
 */
const runTrim = async (width, height, { decodeFails, encoderType = 'image/webp' } = {}) => {
  const draws = []
  let produced = null

  const env = {
    WALLPAPER_TARGET_RATIO: TARGET_RATIO,
    File: FakeFile,
    createImageBitmap: async () => {
      if (decodeFails) throw new Error('decode failed')
      return { close() {} }
    },
    document: {
      createElement(tag) {
        assert.equal(tag, 'canvas', 'the trim must only ever create a canvas')
        const canvas = {
          width: 0,
          height: 0,
          getContext: () => ({
            // Records sx, sy, sw, sh — the bitmap itself is not needed.
            drawImage: (_bitmap, ...rect) => draws.push(rect),
          }),
          toBlob(cb) {
            produced = { width: canvas.width, height: canvas.height }
            cb(encoderType ? { type: encoderType } : null)
          },
        }
        return canvas
      },
    },
  }

  const html = readFileSync(ADMIN_HTML, 'utf8')
  const names = Object.keys(env)
  // eslint-disable-next-line no-new-func
  const factory = new Function(
    ...names,
    `${extractFunction(html, 'normaliseWallpaper')}\nreturn normaliseWallpaper;`,
  )
  const normaliseWallpaper = factory(...names.map((n) => env[n]))

  const original = new FakeFile(['bytes'], 'wall.webp', { type: 'image/webp' })
  const result = await normaliseWallpaper(original, { width, height })

  return {
    passedThrough: result === original,
    result,
    produced,
    draw: draws[0] ?? null,
  }
}

test('an already-8:3 upload is passed through untouched', async () => {
  // No re-encode means no generation loss for the common case of artwork the
  // author already exported to the spec.
  for (const [w, h] of [[1440, 540], [1920, 720], [2400, 900]]) {
    const { passedThrough, draw } = await runTrim(w, h)
    assert.equal(passedThrough, true, `${w}x${h} must not be re-encoded`)
    assert.equal(draw, null, `${w}x${h} must not be drawn to a canvas at all`)
  }
})

test('a 16:9 upload is cropped to the band, evenly top and bottom', async () => {
  // The live wallpaper's shape. 1920 / (8/3) = 720, so 180 comes off each edge.
  //
  // Eight numbers, because drawImage takes the SOURCE rect and then the
  // DESTINATION rect: sx, sy, sw, sh, dx, dy, dw, dh. Pinning all eight also
  // proves the crop is painted back at the canvas origin at full size, so the
  // stored file cannot end up offset or scaled inside its own frame.
  const { passedThrough, draw, result, produced } = await runTrim(1920, 1080)
  assert.equal(passedThrough, false)
  assert.deepEqual(draw, [0, 180, 1920, 720, 0, 0, 1920, 720])
  assert.deepEqual(produced, { width: 1920, height: 720 })
  assert.equal(result.type, 'image/webp')
  assert.equal(result.name, 'wall.webp', 'the original file name is preserved')
})

test('an over-wide upload keeps its height and is cropped at the sides', async () => {
  const { draw } = await runTrim(3000, 800)
  assert.deepEqual(draw, [434, 0, 2133, 800, 0, 0, 2133, 800])
})

test('a taller-than-band upload is cropped top and bottom', async () => {
  const { draw } = await runTrim(1000, 1000)
  // 375 is odd inside 1000, so each margin is 312.5 and Math.round takes the half
  // UP: 313 above. Asserting 312 would be asserting a bug in the test.
  assert.deepEqual(draw, [0, 313, 1000, 375, 0, 0, 1000, 375])
})

test('every crop lands on the band ratio and stays inside the source', async () => {
  for (const [w, h] of [[1920, 1080], [3000, 800], [1000, 1000], [1024, 768], [3840, 2160]]) {
    const { draw, produced } = await runTrim(w, h)
    const [sx, sy, sw, sh] = draw
    assert.deepEqual(produced, { width: sw, height: sh },
      `${w}x${h}: the canvas must be exactly the cropped region`)
    assert.ok(
      Math.abs(sw / sh - TARGET_RATIO) / TARGET_RATIO <= 0.02,
      `${w}x${h} cropped to ${sw}x${sh} (${(sw / sh).toFixed(4)}) is not 8:3`,
    )
    // Staying inside the source matters: drawImage with a rect that runs past the
    // edge paints transparent bands into the stored artwork.
    assert.ok(sx >= 0 && sy >= 0, `${w}x${h}: negative crop origin`)
    assert.ok(sx + sw <= w, `${w}x${h}: the crop runs off the right edge`)
    assert.ok(sy + sh <= h, `${w}x${h}: the crop runs off the bottom edge`)
  }
})

test('a decode failure uploads the original rather than failing', async () => {
  const { passedThrough } = await runTrim(1920, 1080, { decodeFails: true })
  assert.equal(passedThrough, true)
})

test('a browser that cannot encode WebP uploads the original', async () => {
  // toBlob silently falls back to PNG where WebP encoding is unavailable, and the
  // server accepts WebP only — so a wrong type must mean "keep the original".
  const { passedThrough } = await runTrim(1920, 1080, { encoderType: 'image/png' })
  assert.equal(passedThrough, true)
})

test('a null blob uploads the original rather than crashing', async () => {
  const { passedThrough } = await runTrim(1920, 1080, { encoderType: null })
  assert.equal(passedThrough, true)
})
