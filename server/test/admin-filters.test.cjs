/**
 * Filter regression tests for server/admin.html
 *
 * Runs the real filter functions extracted from the page against a JSDOM-like
 * minimal DOM stub, so we test the shipped code rather than a re-implementation.
 *
 * Usage: node test/admin-filters.test.js
 */
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const HTML = path.join(__dirname, '..', 'admin.html');
const html = fs.readFileSync(HTML, 'utf8');

// ---------------------------------------------------------------- extract ---
// Pull the single inline <script> block (the page has exactly one).
const scriptMatch = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/i.exec(html);
if (!scriptMatch) throw new Error('no inline script block found');
const pageScript = scriptMatch[1];

// ------------------------------------------------------------------- dom ----
// Minimal DOM good enough for the filter code paths.
function makeDom(ids) {
  const els = {};
  for (const id of ids) {
    els[id] = { id, value: '', textContent: '', innerHTML: '', style: {}, disabled: false,
      classList: { add(){}, remove(){}, toggle(){} } };
  }
  return {
    els,
    getElementById: (id) => (id in els ? els[id] : null),
    querySelectorAll: () => [],
    createElement: (tag) => ({ tagName: tag, style: {}, classList: { add(){}, remove(){}, toggle(){} },
      appendChild(){}, setAttribute(){}, value: '', textContent: '', innerHTML: '' }),
    body: { appendChild(){}, removeChild(){} },
    addEventListener: () => {},
  };
}

function runPage(dom, extraGlobals) {
  const sandbox = {
    document: dom,
    window: {},
    console,
    fetch: async () => { throw new Error('fetch not stubbed'); },
    setTimeout, clearTimeout, setInterval, clearInterval,
    Number, Math, Date, JSON, String, Array, Object, RegExp, Error, Boolean, parseInt, parseFloat, isNaN,
    ...extraGlobals,
  };
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(pageScript, sandbox, { filename: 'admin.html:inline' });
  // `let` declarations live in the context's lexical scope, not as own
  // properties of the sandbox object, so they are NOT reachable from Node.
  // Expose the page's mutable state via expressions evaluated inside the same
  // context. Test scaffolding only - the page source is untouched.
  sandbox.api = {
    get: (expr) => vm.runInContext(expr, sandbox),
    set: (name, value) => { sandbox.__tmp = value; vm.runInContext(`${name} = __tmp;`, sandbox); },
    call: (fn, ...args) => {
      sandbox.__fn = sandbox[fn];
      sandbox.__args = args;
      return vm.runInContext('__fn(...__args)', sandbox);
    },
  };
  return sandbox;
}

// Thin wrapper so tests read cleanly and never touch `let` bindings directly.
function S(sb) {
  return {
    set tracks(v) { sb.api.set('tracks', v); },
    get tracks() { return sb.api.get('tracks'); },
    set album(v) { sb.api.set('filterAlbum', v); },
    set status(v) { sb.api.set('filterStatus', v); },
    set dmin(v) { sb.api.set('filterDurMin', v); },
    set dmax(v) { sb.api.set('filterDurMax', v); },
    set karaoke(v) { sb.api.set('filterKaraoke', v); },
    set sync(v) { sb.api.set('filterSync', v); },
    set ringtone(v) { sb.api.set('filterRingtone', v); },
    set pageSize(v) { sb.api.set('trackPageSize', v); },
    set page(v) { sb.api.set('trackPage', v); },
    get album() { return sb.api.get('filterAlbum'); },
    get ringtone() { return sb.api.get('filterRingtone'); },
    get dmin() { return sb.api.get('filterDurMin'); },
    get page() { return sb.api.get('trackPage'); },
    filtered: () => sb.api.call('filteredTracks'),
    clear: () => sb.api.call('clearTrackFilters'),
    changePage: (d) => sb.api.call('changeTrackPage', d),
    apply: () => sb.api.call('applyTrackFilters'),
  };
}

// The set of ids the filter row is expected to own (per the markup).
const FILTER_IDS = [
  'searchInput', 'filterArtist', 'filterAlbum', 'filterLanguage', 'filterStatus',
  'filterSync', 'filterKaraoke', 'filterRingtone', 'filterDurMin', 'filterDurMax',
  'clearFiltersBtn', 'tbody', 'count', 'trackPagination', 'trackPageInfo',
  'trackPrevBtn', 'trackNextBtn', 'pageSizeSel',
];

let pass = 0, fail = 0;
function check(name, fn) {
  try { fn(); console.log('  PASS  ' + name); pass++; }
  catch (e) { console.log('  FAIL  ' + name + '\n          -> ' + e.message); fail++; }
}
function assert(cond, msg) { if (!cond) throw new Error(msg || 'assertion failed'); }

// ------------------------------------------------------------------ tests ---
console.log('\n=== admin.html filter tests ===\n');

console.log('[1] applyTrackFilters must not throw when duration inputs exist');
check('applyTrackFilters() completes without throwing', () => {
  const dom = makeDom(FILTER_IDS);
  const sb = runPage(dom);
  S(sb).apply();
});

console.log('\n[2] applyTrackFilters must survive MISSING duration inputs (current bug)');
check('applyTrackFilters() tolerates absent #filterDurMin/#filterDurMax', () => {
  const ids = FILTER_IDS.filter((i) => i !== 'filterDurMin' && i !== 'filterDurMax');
  const dom = makeDom(ids);
  const sb = runPage(dom);
  S(sb).apply();
});

console.log('\n[3] every filter control the JS reads must exist in the markup');
check('all filter ids referenced by applyTrackFilters exist in markup', () => {
  const needed = ['filterArtist', 'filterAlbum', 'filterDurMin', 'filterDurMax',
    'filterLanguage', 'filterStatus', 'filterSync', 'filterKaraoke', 'filterRingtone'];
  const missing = needed.filter((id) => !new RegExp('id="' + id + '"').test(html));
  assert(missing.length === 0, 'missing from markup: ' + missing.join(', '));
});

console.log('\n[4] filteredTracks() semantics');
check('album filter matches exact album, ignores whitespace', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', title: 'A', album: 'Ganesha Lahari', status: 'free' },
    { id: '2', title: 'B', album: 'Govinda Lahari ', status: 'free' },
  ];
  s.album = 'Ganesha Lahari';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '1', 'expected only track 1, got ' + out.map(t=>t.id));
});

check('status filter defaults missing status to free', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', title: 'A' }, { id: '2', title: 'B', status: 'paid' }];
  s.status = 'free';
  assert(s.filtered().length === 1, 'expected 1 free track');
});

check('duration min/max filter is inclusive on both ends', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', duration: 100 }, { id: '2', duration: 200 }, { id: '3', duration: 300 },
  ];
  s.dmin = '100'; s.dmax = '300';
  assert(s.filtered().length === 3, 'inclusive bounds should keep all 3');
  s.dmin = '150'; s.dmax = '250';
  assert(s.filtered().length === 1, 'expected only the 200s track');
});

check('karaoke filter distinguishes path present/absent', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', karaoke_storage_path: 'a.mp4' },
    { id: '2', karaoke_storage_path: '   ' },
    { id: '3' },
  ];
  s.karaoke = 'yes'; assert(s.filtered().length === 1, 'yes -> 1');
  s.karaoke = 'no';  assert(s.filtered().length === 2, 'no -> 2');
});

check('ringtone filter distinguishes path present/absent', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', ringtone_storage_path: 'r.mp3' },
    { id: '2' },
  ];
  s.ringtone = 'yes'; assert(s.filtered().length === 1, 'yes -> 1');
  s.ringtone = 'no';  assert(s.filtered().length === 1, 'no -> 1');
});

check('sync filter treats timestamp-only LRC as NOT having lyrics', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', synced_lyrics: '[00:01.00]real text' },
    { id: '2', synced_lyrics: '[00:01.00]' },
  ];
  s.sync = 'te';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '1', 'timestamp-only must not count as synced');
});

check('sync "any" requires all three languages', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', synced_lyrics: '[00:01.00]a', synced_lyrics_en: '[00:01.00]b', synced_lyrics_hi: '[00:01.00]c' },
    { id: '2', synced_lyrics: '[00:01.00]a', synced_lyrics_en: '[00:01.00]b' },
  ];
  s.sync = 'any';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '1', 'only track 1 has all three');
});

check('combined filters AND together', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', album: 'X', status: 'free' },
    { id: '2', album: 'X', status: 'paid' },
    { id: '3', album: 'Y', status: 'free' },
  ];
  s.album = 'X'; s.status = 'free';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '1', 'expected only track 1');
});

check('empty filter state returns all tracks', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1' }, { id: '2' }, { id: '3' }];
  assert(s.filtered().length === 3, 'no filters should return all');
});

console.log('\n[5] clearTrackFilters() resets every filter');
check('clearTrackFilters() zeroes all filter state and completes', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', album: 'X' }];
  s.album = 'X'; s.ringtone = 'yes'; s.dmin = '10';
  s.clear();
  assert(s.album === '', 'filterAlbum not cleared');
  assert(s.ringtone === '', 'filterRingtone not cleared');
  assert(s.dmin === '', 'filterDurMin not cleared');
  assert(s.filtered().length === 1, 'should show all tracks after clear');
});

console.log('\n[6] changeTrackPage() pagination bounds');
check('changeTrackPage does not exceed available pages', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = Array.from({ length: 25 }, (_, i) => ({ id: String(i), title: 'T' + i }));
  s.pageSize = 20; s.page = 1;
  s.changePage(1);
  assert(s.page === 2, 'should advance to page 2');
  s.changePage(1);
  assert(s.page === 2, 'must not advance past last page');
  s.changePage(-5);
  assert(s.page === 1, 'must not go below page 1');
});

console.log('\n[7] duration input parsing robustness');
check('non-numeric duration input is treated as 0, not NaN', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', duration: 0 }, { id: '2', duration: 500 }];
  s.dmin = 'abc';
  const out = s.filtered();
  assert(out.length >= 1, 'must not silently drop everything on bad input');
});

console.log('\n[8] search filter');
check('search matches title, artist, album and tags case-insensitively', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [
    { id: '1', title: 'Ganesha Song', album: 'A', tags: 'x' },
    { id: '2', title: 'Rama Song', album: 'B', tags: 'bhakti' },
  ];
  sb.api.set('trackSearch', 'ganesha');
  assert(s.filtered().length === 1, 'title search should match 1');
  sb.api.set('trackSearch', 'BHAKTI');
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '2', 'tags search must be case-insensitive');
  sb.api.set('trackSearch', '');
  assert(s.filtered().length === 2, 'cleared search returns all');
});

console.log('\n[9] duration range edge cases (hardening)');
check('reversed range (min > max) still returns the intended tracks', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', duration: 100 }, { id: '2', duration: 200 }, { id: '3', duration: 300 }];
  s.dmin = '250'; s.dmax = '150';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '2', 'reversed range should be swapped, got ' + out.length);
});

check('only min set leaves max unbounded', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', duration: 100 }, { id: '2', duration: 900 }];
  s.dmin = '500'; s.dmax = '';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '2', 'min-only should keep the longer track');
});

check('only max set leaves min unbounded', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', duration: 100 }, { id: '2', duration: 900 }];
  s.dmin = ''; s.dmax = '500';
  const out = s.filtered();
  assert(out.length === 1 && out[0].id === '1', 'max-only should keep the shorter track');
});

check('negative bound is ignored rather than filtering everything out', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', duration: 100 }, { id: '2', duration: 200 }];
  s.dmin = '-5'; s.dmax = '';
  assert(s.filtered().length === 2, 'negative min should behave as unbounded');
});

check('duration exactly on the bound is included', () => {
  const dom = makeDom(FILTER_IDS); const sb = runPage(dom); const s = S(sb);
  s.tracks = [{ id: '1', duration: 180 }];
  s.dmin = '180'; s.dmax = '180';
  assert(s.filtered().length === 1, 'boundary value must be inclusive');
});

console.log('\n[10] markup/JS contract');
check('duration inputs are wired to applyTrackFilters', () => {
  assert(/id="filterDurMin"[^>]*oninput="applyTrackFilters\(\)"/.test(html), 'filterDurMin not wired');
  assert(/id="filterDurMax"[^>]*oninput="applyTrackFilters\(\)"/.test(html), 'filterDurMax not wired');
});
check('filterArtist dropdown is wired', () => {
  assert(/id="filterArtist"[^>]*onchange="applyTrackFilters\(\)"/.test(html), 'filterArtist not wired');
});
check('clearTrackFilters clears filterArtist too', () => {
  const m = /function clearTrackFilters\(\)\s*\{([\s\S]*?)\n\}/.exec(html);
  assert(m && /filterArtist/.test(m[1]), 'clearTrackFilters omits filterArtist');
});
check('hasFilters considers the ringtone filter', () => {
  assert(/hasFilters\s*=[\s\S]{0,400}filterRingtone/.test(html), 'hasFilters omits filterRingtone');
});

console.log('\n----------------------------------------');
console.log(`PASS ${pass}   FAIL ${fail}`);
console.log('----------------------------------------\n');
process.exit(fail === 0 ? 0 : 1);
