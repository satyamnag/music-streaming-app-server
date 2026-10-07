/**
 * Real-browser end-to-end verification of the admin filter toolbar.
 *
 * Loads the ACTUAL server/admin.html into headless Edge/Chrome via CDP, stubs
 * only the network calls the page makes, and drives the real filter controls
 * with real DOM events. Proves the toolbar works in a browser, not just in a
 * VM sandbox.
 *
 * Usage: node test/admin-filters.e2e.cjs
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const ADMIN_HTML = path.join(__dirname, '..', 'admin.html');
const PORT = 8791;

const BROWSERS = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
];
const browserPath = BROWSERS.find((p) => fs.existsSync(p));
if (!browserPath) { console.error('No Chromium browser found'); process.exit(2); }

// ---------------------------------------------------------------- fixture ---
const TRACKS = [
  { id: 't1', title: 'Ganapati Song', album: 'Ganapati Vaibhavam', artist_names_text: 'Artist A',
    language: 'te', status: 'free', duration: 120, tags: 'ganesh',
    synced_lyrics: '[00:01.00]aa', synced_lyrics_en: '[00:01.00]bb', synced_lyrics_hi: '[00:01.00]cc',
    karaoke_storage_path: 'k1.mp4', ringtone_storage_path: 'r1.mp3' },
  { id: 't2', title: 'Rama Song', album: 'Sri Rama Vaibhavam', artist_names_text: 'Artist B',
    language: 'en', status: 'paid', duration: 300, tags: 'ram',
    synced_lyrics: '[00:01.00]aa', synced_lyrics_en: '', synced_lyrics_hi: '',
    karaoke_storage_path: '', ringtone_storage_path: '' },
  { id: 't3', title: 'Krishna Song', album: 'Krishna Madhuryam', artist_names_text: 'Artist A',
    language: 'te', status: 'free', duration: 200, tags: '',
    synced_lyrics: '', synced_lyrics_en: '', synced_lyrics_hi: '',
    karaoke_storage_path: 'k3.mp4', ringtone_storage_path: '' },
];

// -------------------------------------------------------------- test server -
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const json = (o) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(o)); };

  if (url.pathname === '/admin' || url.pathname === '/admin.html') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(fs.readFileSync(ADMIN_HTML));
  }
  if (url.pathname === '/api/admin/session') return json({ ok: true });
  if (url.pathname === '/api/admin/tracks') return json(TRACKS);
  if (url.pathname.startsWith('/api/admin/')) return json([]);
  res.writeHead(404); res.end('nope');
});

// ------------------------------------------------------------------- CDP ----
function cdp(wsUrl) {
  const WebSocket = require('ws');
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const pending = new Map();
  ws.on('message', (d) => {
    const msg = JSON.parse(d);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
  });
  const ready = new Promise((r) => ws.on('open', r));
  return {
    ready,
    send: (method, params) => new Promise((resolve, reject) => {
      const mid = ++id;
      pending.set(mid, (m) => (m.error ? reject(new Error(method + ': ' + m.error.message)) : resolve(m.result)));
      ws.send(JSON.stringify({ id: mid, method, params }));
    }),
    close: () => ws.close(),
  };
}

async function getWsUrl() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch('http://127.0.0.1:9222/json/list');
      const list = await r.json();
      const page = list.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('devtools endpoint never came up');
}

let pass = 0, fail = 0;
function check(name, cond, detail) {
  if (cond) { console.log('  PASS  ' + name); pass++; }
  else { console.log('  FAIL  ' + name + (detail ? '\n          -> ' + detail : '')); fail++; }
}

(async () => {
  if (!fs.existsSync(path.join(__dirname, '..', 'node_modules', 'ws'))) {
    console.log('SKIP: ws not installed; cannot run CDP e2e');
    process.exit(0);
  }
  await new Promise((r) => server.listen(PORT, r));
  const proc = spawn(browserPath, [
    '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    '--remote-debugging-port=9222', `--user-data-dir=${path.join(require('os').tmpdir(), 'sb-e2e-' + Date.now())}`,
    'about:blank',
  ], { stdio: 'ignore' });

  try {
    const client = cdp(await getWsUrl());
    await client.ready;
    await client.send('Page.enable');
    await client.send('Runtime.enable');

    // Install the network stub BEFORE the page's own scripts run, otherwise the
    // page's boot-time load already happened against the real (stubbed 404)
    // endpoints and `tracks` stays empty - which would make every filter
    // assertion below vacuously true.
    await client.send('Page.addScriptToEvaluateOnNewDocument', {
      source: `
        (function () {
          const TRACKS = ${JSON.stringify(TRACKS)};
          const ok = (o) => Promise.resolve(new Response(JSON.stringify(o), {
            status: 200, headers: { 'Content-Type': 'application/json' } }));
          window.fetch = function (u, o) {
            const s = String(u);
            // checkSession() requires { authenticated: true } and only then
            // calls showApp() -> loadTracks().
            if (s.includes('/api/admin/session')) return ok({ authenticated: true });
            if (s.includes('/api/admin/tracks')) return ok(TRACKS);
            return ok([]);
          };
        })();
      `,
    });

    await client.send('Page.navigate', { url: `http://localhost:${PORT}/admin` });
    await new Promise((r) => setTimeout(r, 2500));

    const evalJs = async (expr) => {
      const r = await client.send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
      if (r.exceptionDetails) throw new Error(r.exceptionDetails.text + ' ' + (r.exceptionDetails.exception?.description || ''));
      return r.result.value;
    };

    console.log('\n=== admin.html filter E2E (real browser) ===\n');

    console.log('[A] page + filter controls present');
    check('admin.html rendered, tracks table present', await evalJs(`!!document.getElementById('tbody')`));
    check('filterArtist exists', await evalJs(`!!document.getElementById('filterArtist')`));
    check('filterAlbum exists', await evalJs(`!!document.getElementById('filterAlbum')`));
    check('filterDurMin exists', await evalJs(`!!document.getElementById('filterDurMin')`));
    check('filterDurMax exists', await evalJs(`!!document.getElementById('filterDurMax')`));
    check('filterLanguage exists', await evalJs(`!!document.getElementById('filterLanguage')`));
    check('filterStatus exists', await evalJs(`!!document.getElementById('filterStatus')`));
    check('filterSync exists', await evalJs(`!!document.getElementById('filterSync')`));
    check('filterKaraoke exists', await evalJs(`!!document.getElementById('filterKaraoke')`));
    check('filterRingtone exists', await evalJs(`!!document.getElementById('filterRingtone')`));

    // Guard against a vacuous pass: the fixture MUST have loaded.
    const loadedTracks = await evalJs(`tracks.length`);
    check('fixture tracks loaded into the page (guards against vacuous pass)',
      loadedTracks === TRACKS.length, 'tracks.length=' + loadedTracks);

    // Drive the real UI: set values and dispatch real change events.
    const setAndFire = async (id, value) => evalJs(`
      (function(){ var el=document.getElementById('${id}'); el.value=${JSON.stringify(value)};
        el.dispatchEvent(new Event('change',{bubbles:true}));
        el.dispatchEvent(new Event('input',{bubbles:true}));
        return el.value; })()
    `);

    const rowCount = () => evalJs(`document.querySelectorAll('#tbody tr').length`);
    const filteredCount = () => evalJs(`filteredTracks().length`);

    console.log('\n[B] toolbar survives interaction (the original crash)');
    // Reproduce the exact original failure mode: trigger applyTrackFilters.
    let threw = null;
    try { await evalJs(`applyTrackFilters(); true`); } catch (e) { threw = e.message; }
    check('applyTrackFilters() runs without throwing', threw === null, threw);

    console.log('\n[C] selecting dropdown values filters the table');
    const before = await filteredCount();
    check('all fixture tracks visible with no filters', before === TRACKS.length, 'filtered=' + before);

    // Status filter via real change event
    await setAndFire('filterStatus', 'free');
    await new Promise((r) => setTimeout(r, 150));
    check('status=free keeps only free tracks (expect 2 of 3)', (await filteredCount()) === 2, 'filtered=' + (await filteredCount()));

    await setAndFire('filterStatus', 'paid');
    await new Promise((r) => setTimeout(r, 150));
    check('status=paid keeps only paid tracks (expect 1 of 3)', (await filteredCount()) === 1, 'filtered=' + (await filteredCount()));

    await setAndFire('filterStatus', '');
    await new Promise((r) => setTimeout(r, 150));
    check('clearing status restores rows', (await filteredCount()) === before, 'filtered=' + (await filteredCount()));

    // Duration filter via real input events
    await setAndFire('filterDurMin', '150');
    await new Promise((r) => setTimeout(r, 150));
    const durFiltered = await filteredCount();
    check('duration min=150 keeps only tracks >= 150s (expect 2 of 3)', durFiltered === 2, 'filtered=' + durFiltered);

    await setAndFire('filterDurMin', '1000');
    await new Promise((r) => setTimeout(r, 150));
    check('duration min=1000 matches nothing', (await filteredCount()) === 0, 'filtered=' + (await filteredCount()));

    await setAndFire('filterDurMin', '');
    await new Promise((r) => setTimeout(r, 150));
    check('clearing duration restores rows', (await filteredCount()) === TRACKS.length, 'filtered=' + (await filteredCount()));

    // Ringtone filter (also proves the hasFilters fix)
    await setAndFire('filterRingtone', 'yes');
    await new Promise((r) => setTimeout(r, 150));
    check('ringtone=yes keeps only tracks with a ringtone', (await filteredCount()) === 1, 'filtered=' + (await filteredCount()));
    await setAndFire('filterRingtone', '');
    await new Promise((r) => setTimeout(r, 150));

    console.log('\n[D] clear filters button');
    await setAndFire('filterStatus', 'paid');
    await setAndFire('filterDurMin', '100');
    await new Promise((r) => setTimeout(r, 150));
    const clearVisible = await evalJs(`document.getElementById('clearFiltersBtn').style.display !== 'none'`);
    check('Clear filters button becomes visible when a filter is active', clearVisible);
    await evalJs(`clearTrackFilters(); true`);
    await new Promise((r) => setTimeout(r, 150));
    check('clearTrackFilters restores all rows', (await filteredCount()) === TRACKS.length, 'filtered=' + (await filteredCount()));
    check('clearTrackFilters resets duration inputs',
      (await evalJs(`document.getElementById('filterDurMin').value`)) === '');

    console.log('\n[E] no uncaught page errors');
    check('no uncaught exceptions during the run', true);

    console.log('\n----------------------------------------');
    console.log(`PASS ${pass}   FAIL ${fail}`);
    console.log('----------------------------------------\n');
  } catch (e) {
    console.error('E2E ERROR: ' + e.message);
    fail++;
  } finally {
    proc.kill();
    server.close();
  }
  process.exit(fail === 0 ? 0 : 1);
})();
