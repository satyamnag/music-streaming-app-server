// Static verification for the admin Auto-Sync Lyrics UI.
//
// Run: node test/auto-sync-admin-ui.test.cjs
//
// admin.html is a single hand-written file with no build step and no bundler,
// so a typo in a function name or an element id fails silently in the browser.
// These checks read the file as text and assert the wiring actually connects:
// every id the script looks up exists in the markup, every handler referenced by
// an onclick exists as a function, and the UI cannot save anything itself.

const fs = require('fs')
const path = require('path')

const ADMIN = path.join(__dirname, '..', 'admin.html')
const html = fs.readFileSync(ADMIN, 'utf8')

let passed = 0
let failed = 0
const out = []

function check(name, fn) {
  try { fn(); passed++; out.push(`  ok   ${name}`) }
  catch (e) { failed++; out.push(`  FAIL ${name}\n       ${e.message}`) }
}

const assert = require('assert')

// The Auto-Sync markup block, isolated so the assertions cannot accidentally
// pass because of some unrelated element elsewhere in the file.
const blockStart = html.indexOf('id="autoSyncPanel"')
const blockEnd = html.indexOf('id="lyricsText"')
const panel = blockStart > -1 ? html.slice(blockStart, blockEnd) : ''

// The script that implements it, isolated the same way.
const jsStart = html.indexOf('async function runAutoSync(')
const jsEnd = html.indexOf('// Switches between the "Track" and "Lyrics" panes')
const js = jsStart > -1 ? html.slice(jsStart, jsEnd) : ''

check('the Auto-Sync panel exists in the Lyrics pane', () => {
  assert.ok(blockStart > -1, 'id="autoSyncPanel" not found in admin.html')
})

check('the Auto-Sync script exists', () => {
  assert.ok(jsStart > -1, 'runAutoSync() not found in admin.html')
})

check('every element id the script reads exists in the panel markup', () => {
  const ids = new Set()
  for (const m of js.matchAll(/getElementById\('([^']+)'\)/g)) ids.add(m[1])
  // Ids legitimately owned by the surrounding editor, not the panel.
  const external = new Set(['lyricsText', 'lvl-sync', 'lang-te', 'editId'])
  for (const id of ids) {
    if (external.has(id)) continue
    assert.ok(html.includes(`id="${id}"`), `script reads #${id} but no element with that id exists`)
  }
})

check('the button handler matches the function name exactly', () => {
  assert.match(panel, /onclick="runAutoSync\(false\)"/, 'button does not call runAutoSync(false)')
})

check('the panel states that nothing is saved', () => {
  assert.match(panel, /Nothing is saved/i, 'the panel must tell the admin nothing is persisted')
})

check('the script never PUTs or POSTs to the track endpoint', () => {
  // The ONLY permitted request is the propose-only auto-sync endpoint. The URL
  // is assembled from a concatenation, so capture the whole expression up to
  // the options object rather than stopping at the first parenthesis.
  const calls = [...js.matchAll(/authedFetch\(([\s\S]*?),\s*\{\s*\n?\s*method:/g)].map((m) => m[1].trim())
  assert.strictEqual(calls.length, 1, `expected exactly one request, found ${calls.length}: ${calls.join(' | ')}`)
  assert.ok(/auto-sync/.test(calls[0]), `the single request must target /auto-sync, found: ${calls[0]}`)
  assert.ok(!/method:\s*'PUT'/.test(js), 'the Auto-Sync UI must not issue a PUT')
})

check('the proposal is written into the shared Sync Telugu textarea', () => {
  assert.match(js, /lyricsLevel\s*=\s*'sync'/, 'must switch the editor to Sync')
  assert.match(js, /lyricsLang\s*=\s*'te'/, 'must switch the editor to Telugu')
  assert.match(js, /lyricsText/, 'must write into #lyricsText')
})

check('the response body is read only once', () => {
  // A Response body is single-use: calling res.json() after res.text() throws
  // "Body is unusable", which would make the feature fail exactly when it needs
  // to report an error.
  const bodyReads = [...js.matchAll(/await res\.(json|text)\(\)/g)].map((m) => m[1])
  assert.strictEqual(bodyReads.length, 1, `response body read ${bodyReads.length} times: ${bodyReads.join(', ')}`)
})

check('the panel is cleared when a different track is loaded', () => {
  const loadStart = html.indexOf('function loadSyncLyricsInto(')
  const loadEnd = html.indexOf('function closeSyncLyrics()')
  const loader = html.slice(loadStart, loadEnd)
  assert.match(loader, /autoSyncReport/, 'loadSyncLyricsInto must clear #autoSyncReport')
})

check('the panel is cleared when the modal closes', () => {
  const closeStart = html.indexOf('function closeSyncLyrics()')
  const closer = html.slice(closeStart, closeStart + 400)
  assert.match(closer, /autoSyncReport/, 'closeSyncLyrics must clear #autoSyncReport')
})

check('the re-run override is off by default', () => {
  const box = /<input type="checkbox" id="autoSyncForce"[^>]*>/.exec(panel)
  assert.ok(box, 'the force checkbox is missing')
  assert.ok(!/\bchecked\b/.test(box[0]), 'the force checkbox must not be pre-checked')
})

check('the API key is never referenced in the UI', () => {
  assert.ok(!/deepgram_api_key|DEEPGRAM_API_KEY/i.test(html), 'the UI must not mention the API key')
})

for (const line of out) console.log(line)
console.log(`\n${passed} passed, ${failed} failed, ${passed + failed} total`)
process.exit(failed ? 1 : 0)
