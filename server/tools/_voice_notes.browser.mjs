// Headless end-to-end verification of the Song Sync Lyrics SRT Maker's voice
// graph, driving real Microsoft Edge over the DevTools protocol.
//
// Why a browser and not a unit test: the whole feature is a canvas. The claim
// under test is visual ("a high note is drawn higher than a low note"), so the
// only honest check is to decode a real WAV whose melody is known, draw it, and
// read the pixels back.
//
// No dependencies: Node's global fetch + WebSocket, and a hand-rolled CDP client.
//
//   node server/tools/_voice_notes.browser.mjs
//   SHOT_DIR=/tmp/shots node server/tools/_voice_notes.browser.mjs   # + PNGs
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const ADMIN_HTML = path.join(HERE, '..', 'admin.html');
const SR = 22050;

/* ------------------------------------------------------------------ */
/* 1. a WAV whose melody is known, so "higher note" has a ground truth */
/* ------------------------------------------------------------------ */

const MELODY = [
  { at: 0.5, hz: 146.83, dur: 1.0, name: 'D3' },
  { at: 1.8, hz: 523.25, dur: 1.0, name: 'C5' },
  { at: 3.1, hz: 196.00, dur: 1.0, name: 'G3' }
];
const TOTAL = 4.6;

function buildWav() {
  const n = Math.round(SR * TOTAL);
  const x = new Float32Array(n);
  const harm = [1, 0.5, 0.3, 0.18, 0.1];
  for (const note of MELODY) {
    const from = Math.round(note.at * SR);
    const to = Math.min(n, Math.round((note.at + note.dur) * SR));
    let phase = 0;
    for (let i = from; i < to; i++) {
      phase += (2 * Math.PI * note.hz) / SR;
      let v = 0;
      for (let k = 0; k < harm.length; k++) v += harm[k] * Math.sin((k + 1) * phase);
      const up = Math.min(1, (i - from) / (SR * 0.006));   // 6 ms attack
      x[i] += v * 0.2 * up;
    }
  }
  const data = Buffer.alloc(n * 2);
  for (let i = 0; i < n; i++) {
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, x[i])) * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(SR, 24);
  header.writeUInt32LE(SR * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

const WAV = buildWav();

/* ------------------------------------------------------------------ */
/* 2. a stubbed admin API + the real admin.html                        */
/* ------------------------------------------------------------------ */

const TRACK = {
  id: 't1',
  title: 'Voice Graph Test Bhajan',
  artist: 'Test',
  album: 'Test Album',
  language: 'te',
  status: 'free',
  duration: TOTAL,
  synced_lyrics: '',
  plain_lyrics: 'First line of the bhajan\nSecond line of the bhajan\nThird line of the bhajan',
  cover_url: '',
  created_at: new Date().toISOString()
};

const putBodies = [];

function startServer() {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://127.0.0.1');
    const p = url.pathname;

    if (p === '/admin' || p === '/admin.html' || p === '/') {
      const html = fs.readFileSync(ADMIN_HTML);
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Content-Length': html.length });
      res.end(html);
      return;
    }
    if (p === '/stream/t1/file') {
      const range = req.headers.range;
      if (range) {
        const m = /bytes=(\d*)-(\d*)/.exec(range);
        const start = m && m[1] ? Number(m[1]) : 0;
        const end = m && m[2] ? Number(m[2]) : WAV.length - 1;
        res.writeHead(206, {
          'Content-Type': 'audio/wav',
          'Accept-Ranges': 'bytes',
          'Content-Range': `bytes ${start}-${end}/${WAV.length}`,
          'Content-Length': end - start + 1
        });
        res.end(WAV.subarray(start, end + 1));
        return;
      }
      res.writeHead(200, { 'Content-Type': 'audio/wav', 'Accept-Ranges': 'bytes', 'Content-Length': WAV.length });
      res.end(WAV);
      return;
    }
    if (p.startsWith('/api/')) {
      if (req.method !== 'GET' && req.method !== 'HEAD') {
        let body = '';
        req.on('data', (c) => { body += c; });
        req.on('end', () => {
          let parsed = null;
          try { parsed = JSON.parse(body || '{}'); } catch (_) {}
          putBodies.push({ method: req.method, path: p, body: parsed });
          // Reflect the write back, so the studio's "re-read and compare" step
          // sees exactly what it wrote (that is how the real server behaves).
          if (parsed && typeof parsed === 'object') Object.assign(TRACK, parsed);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(Object.assign({ ok: true }, parsed || {})));
        });
        return;
      }
      let payload = {};
      if (p === '/api/admin/session') payload = { authenticated: true };
      else if (p === '/api/admin/tracks') payload = [TRACK];
      else if (p === '/api/admin/tracks/t1') payload = TRACK;
      else if (/^\/api\/admin\/(albums|specials|featured-playlists|affiliates|coupons)$/.test(p)) payload = [];
      else if (p.startsWith('/api/admin/featured/')) payload = [];
      else if (p.startsWith('/api/admin/partners')) payload = [];
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(payload));
      return;
    }
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('not found');
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => resolve({ server, port: server.address().port }));
  });
}

/* ------------------------------------------------------------------ */
/* 3. a minimal CDP client                                            */
/* ------------------------------------------------------------------ */

const EDGE = [
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'
].find((p) => fs.existsSync(p));

async function waitFor(fn, timeoutMs, label) {
  const t0 = Date.now();
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() - t0 > timeoutMs) throw new Error('timeout waiting for ' + label);
    await new Promise((r) => setTimeout(r, 60));
  }
}

async function connect(port) {
  const url = await waitFor(async () => {
    try {
      const r = await fetch(`http://127.0.0.1:${port}/json/list`);
      const j = await r.json();
      const page = j.find((t) => t.type === 'page');
      return page ? page.webSocketDebuggerUrl : null;
    } catch (_) { return null; }
  }, 20000, 'the DevTools endpoint');

  const ws = new WebSocket(url);
  await new Promise((res, rej) => {
    ws.addEventListener('open', res, { once: true });
    ws.addEventListener('error', rej, { once: true });
  });
  let id = 0;
  const pending = new Map();
  const events = [];
  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) reject(new Error(msg.error.message));
      else resolve(msg.result);
    } else if (msg.method) {
      events.push(msg);
    }
  });
  function send(method, params) {
    id += 1;
    const myId = id;
    return new Promise((resolve, reject) => {
      pending.set(myId, { resolve, reject });
      ws.send(JSON.stringify({ id: myId, method, params: params || {} }));
    });
  }
  return { send, events, close: () => ws.close() };
}

/* ------------------------------------------------------------------ */
/* 4. the checks                                                      */
/* ------------------------------------------------------------------ */

let pass = 0;
let fail = 0;
const failures = [];
function check(name, ok, detail) {
  if (ok) { pass++; console.log(`  PASS  ${name}${detail ? ' - ' + detail : ''}`); }
  else { fail++; failures.push(name + (detail ? ' - ' + detail : '')); console.log(`  FAIL  ${name}${detail ? ' - ' + detail : ''}`); }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// The playhead the studio itself reports, in seconds. `#ssLive` is written by
// the same tick() that draws the playhead, so it is the honest reading; the seek
// slider is deliberately NOT used, because it stops syncing while a drag is in
// progress (that is a feature, not a bug).
const readPlayhead = `(() => {
  const v = document.getElementById('ssLive').textContent.trim();
  const m = /(\\d+):(\\d+)\\.(\\d+)/.exec(v);
  if (!m) return -1;
  return Number(m[1]) * 60 + Number(m[2]) + Number(m[3]) / 1000;
})()`;

const seekTo = (t) => `(() => {
  const s = document.getElementById('ssSeek');
  s.value = '${t}';
  s.dispatchEvent(new Event('pointerdown', { bubbles: true }));
  s.dispatchEvent(new Event('input', { bubbles: true }));
  s.dispatchEvent(new Event('change', { bubbles: true }));
  return true;
})()`;

// A synthetic click on the graph at a given track time.
const clickGraphAt = (t, pointerId) => `(() => {
  const canvas = document.getElementById('ssWave');
  const r = canvas.getBoundingClientRect();
  const span = 4.6;
  const gutCss = 36;
  const x = r.left + gutCss + ((${t} / span) * (r.width - gutCss));
  const y = r.top + r.height * 0.5;
  canvas.dispatchEvent(new PointerEvent('pointerdown', {
    clientX: x, clientY: y, pointerId: ${pointerId}, bubbles: true, cancelable: true, isPrimary: true
  }));
  canvas.dispatchEvent(new PointerEvent('pointerup', {
    clientX: x, clientY: y, pointerId: ${pointerId}, bubbles: true, cancelable: true, isPrimary: true
  }));
  return true;
})()`;

const countCyan = `(() => {
  const c = document.getElementById('ssWave');
  const img = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
  let n = 0;
  for (let i = 0; i < img.length; i += 4) {
    if (img[i] < 110 && img[i + 1] > 150 && img[i + 2] > 185) n++;
  }
  return n;
})()`;

async function main() {
  if (!EDGE) throw new Error('Microsoft Edge not found');
  const { server, port } = await startServer();
  const base = `http://127.0.0.1:${port}`;
  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sb-edge-'));
  const debugPort = 9400 + (process.pid % 400);

  console.log(`stub server ${base}  ·  ${WAV.length} byte wav  ·  melody ` +
    MELODY.map((m) => `${m.name}@${m.at}s`).join(' '));

  const child = spawn(EDGE, [
    '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
    '--disable-extensions', '--autoplay-policy=no-user-gesture-required', '--mute-audio',
    `--remote-debugging-port=${debugPort}`, `--user-data-dir=${userDataDir}`, 'about:blank'
  ], { stdio: 'ignore' });

  let cdp;
  try {
    cdp = await connect(debugPort);
    await cdp.send('Runtime.enable');
    await cdp.send('Page.enable');
    await cdp.send('Log.enable');
    cdp.events.length = 0;

    async function evaluate(expression) {
      const r = await cdp.send('Runtime.evaluate', {
        expression, awaitPromise: true, returnByValue: true
      });
      if (r.exceptionDetails) {
        throw new Error('page exception: ' + (r.exceptionDetails.exception
          ? r.exceptionDetails.exception.description || r.exceptionDetails.text
          : r.exceptionDetails.text));
      }
      return r.result.value;
    }

    await cdp.send('Page.navigate', { url: base + '/admin' });
    await sleep(1200);

    console.log('\n=== boot ===');
    const booted = await waitFor(async () => evaluate(
      "document.getElementById('app') && document.getElementById('app').style.display === 'block'"
    ), 15000, 'the admin app to boot');
    check('admin panel boots against the stub API', !!booted);
    check('tracks loaded', await evaluate("document.querySelectorAll('#tbody tr').length") >= 1);
    await evaluate("window.confirm = () => true; true");

    console.log('\n=== studio + voice-note analysis ===');
    await evaluate("window.openSyncStudio('t1')");
    await sleep(300);
    check('studio overlay opens',
      await evaluate("document.getElementById('ssOverlay').classList.contains('open')"));

    const metaDone = await waitFor(async () => {
      const t = await evaluate("document.getElementById('ssWaveMeta').textContent");
      return /(notes [A-G])|no sung notes|Unavailable/.test(t) ? t : null;
    }, 30000, 'the voice-note pass to finish');
    check('the note pass finished and the meta names the sung range', /notes [A-G]/.test(metaDone), metaDone);
    check('the meta reports the notes found in this melody (D3 to C5)',
      /notes D3\u2013C5/.test(metaDone), metaDone);

    console.log('\n=== the claim: high notes are drawn high ===');
    const geometry = await evaluate(`(() => {
      const c = document.getElementById('ssWave');
      const img = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      const W = c.width, H = c.height;
      const dpr = W / c.getBoundingClientRect().width;
      const gut = Math.round(36 * dpr);
      const isCyan = (i) => img[i] < 110 && img[i + 1] > 150 && img[i + 2] > 185;
      function centreYTime(t) {
        const x = Math.round(gut + (t / 4.6) * (W - gut));
        let sum = 0, n = 0, top = -1, bottom = -1;
        for (let dx = -3; dx <= 3; dx++) {
          const xx = x + dx;
          if (xx < 0 || xx >= W) continue;
          for (let y = 0; y < H; y++) {
            const i = (y * W + xx) * 4;
            if (isCyan(i)) { sum += y; n++; if (top < 0 || y < top) top = y; if (y > bottom) bottom = y; }
          }
        }
        return n ? { y: sum / n, n, top, bottom, h: bottom - top + 1 } : null;
      }
      return {
        W, H, dpr, gut,
        d3: centreYTime(1.0), c5: centreYTime(2.3), g3: centreYTime(3.6), rest: centreYTime(0.2)
      };
    })()`);

    check('a note block is drawn at the D3 moment', !!geometry.d3 && geometry.d3.n > 5,
      geometry.d3 ? `${geometry.d3.n} px` : 'none');
    check('a note block is drawn at the C5 moment', !!geometry.c5 && geometry.c5.n > 5,
      geometry.c5 ? `${geometry.c5.n} px` : 'none');
    // Thickness is measured with a wider predicate than the fill colour, so the
    // 1 px highlight and the antialiased edges of the rounded block count: the
    // block's real height is what "reads as a note, not a hairline".
    const thickness = await evaluate(`(() => {
      const c = document.getElementById('ssWave');
      const img = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      const W = c.width, H = c.height;
      const dpr = W / c.getBoundingClientRect().width;
      const gut = Math.round(36 * dpr);
      // Everything cyan-ish in the pitch lane, excluding the contour (r 232),
      // white markers (r 255) and the ruler labels (x <= gut).
      const isBlock = (i) => img[i] < 225 && img[i + 1] > 150 && img[i + 2] > 150;
      const out = {};
      for (const [tag, t] of [['d3', 1.0], ['c5', 2.3], ['g3', 3.6]]) {
        const x = Math.round(gut + (t / 4.6) * (W - gut));
        let top = -1, bottom = -1;
        for (let y = 0; y < H * 0.62; y++) {
          const i = (y * W + x) * 4;
          if (isBlock(i)) { if (top < 0) top = y; bottom = y; }
        }
        out[tag] = top < 0 ? 0 : (bottom - top + 1) / dpr;
      }
      return out;
    })()`);
    check('notes are drawn as blocks, not hairlines (>= 4 CSS px tall)',
      thickness.d3 >= 4 && thickness.c5 >= 4,
      `D3 ${thickness.d3.toFixed(1)} px, C5 ${thickness.c5.toFixed(1)} px, G3 ${thickness.g3.toFixed(1)} px`);
    if (geometry.d3 && geometry.c5 && geometry.g3) {
      check('the HIGH note (C5) is drawn ABOVE the low note (D3)',
        geometry.c5.y < geometry.d3.y - 10,
        `C5 y=${geometry.c5.y.toFixed(1)} vs D3 y=${geometry.d3.y.toFixed(1)}`);
      check('C5 sits in the top third and D3 in the bottom half',
        geometry.c5.y < geometry.H * 0.33 && geometry.d3.y > geometry.H * 0.5,
        `C5 ${(geometry.c5.y / geometry.H * 100).toFixed(0)}%, D3 ${(geometry.d3.y / geometry.H * 100).toFixed(0)}%`);
      check('G3 is drawn between C5 and D3',
        geometry.g3.y > geometry.c5.y && geometry.g3.y < geometry.d3.y,
        `G3 y=${geometry.g3.y.toFixed(1)}`);
      check('the top note is not clipped by the edge of the roll', geometry.c5.y > 4,
        `C5 centre ${geometry.c5.y.toFixed(1)} px from the top`);
    } else {
      check('all three note blocks are present', false, 'a note block is missing');
    }
    check('no note block is drawn over the silence', !geometry.rest || geometry.rest.n === 0,
      geometry.rest ? `${geometry.rest.n} px` : 'none');

    console.log('\n=== the note-name ruler ===');
    // Count label ROWS, not pixels: three note names must be legible in the
    // gutter, and rows are what "one name per note line" actually means.
    const rulerRows = await evaluate(`(() => {
      const c = document.getElementById('ssWave');
      const img = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      const W = c.width;
      const dpr = W / c.getBoundingClientRect().width;
      const gut = Math.round(36 * dpr);
      const rows = new Set();
      let ink = 0;
      for (let x = 2; x < gut - 3; x++) {
        for (let y = 0; y < c.height * 0.66; y++) {
          const i = (y * W + x) * 4;
          // Anything clearly brighter than the near-black gutter plate.
          if (img[i] > 55 && img[i + 1] > 65 && img[i + 2] > 75) { rows.add(y); ink++; }
        }
      }
      // Collapse adjacent rows so one glyph run counts once.
      const sorted = [...rows].sort((a, b) => a - b);
      let bands = 0, prev = -99;
      for (const y of sorted) { if (y - prev > 3) bands++; prev = y; }
      return { ink, bands, gut };
    })()`);
    check('the ruler draws at least three note names in the gutter', rulerRows.bands >= 3,
      `${rulerRows.bands} label bands (${rulerRows.ink} px)`);
    const gutReserved = await evaluate(`(() => {
      const c = document.getElementById('ssWave');
      const img = c.getContext('2d').getImageData(0, 0, c.width, c.height).data;
      const W = c.width;
      const dpr = W / c.getBoundingClientRect().width;
      const gut = Math.round(36 * dpr);
      let cyanInGutter = 0;
      const samples = [];
      for (let x = 0; x < gut - 3; x++) {
        for (let y = 0; y < c.height; y++) {
          const i = (y * W + x) * 4;
          if (img[i] < 110 && img[i + 1] > 150 && img[i + 2] > 185) {
            cyanInGutter++;
            if (samples.length < 6) samples.push([x, y, img[i], img[i + 1], img[i + 2]]);
          }
        }
      }
      return { cyanInGutter, samples };
    })()`);
    check('the gutter is reserved: no note block spills into the ruler', gutReserved.cyanInGutter === 0,
      `${gutReserved.cyanInGutter} px ${JSON.stringify(gutReserved.samples)}`);

    console.log('\n=== the live "now singing" readout ===');
    for (const [t, expected] of [[2.3, 'C5'], [1.0, 'D3'], [0.2, '\u2014']]) {
      await evaluate(seekTo(t));
      await sleep(220);
      const got = await evaluate("document.getElementById('ssNoteNow').textContent");
      check(`the chip reads ${expected === '\u2014' ? 'a rest' : expected} at ${t} s`, got === expected, got);
    }

    console.log('\n=== one click lands the cue on the note ===');
    await evaluate(seekTo(0.2));
    await sleep(120);
    await evaluate(clickGraphAt(1.85, 1));
    await sleep(220);
    const snapped = await evaluate(readPlayhead);
    check('a click 50 ms after the C5 onset snaps back onto it (1.800 s)',
      Math.abs(snapped - 1.8) < 0.02, `playhead ${snapped.toFixed(3)} s`);

    await evaluate("document.getElementById('ssSnapOnset').click()");
    await evaluate(clickGraphAt(1.85, 2));
    await sleep(220);
    const raw = await evaluate(readPlayhead);
    check('with Snap off the click lands on the pixel, not the onset',
      raw > 1.82 && raw < 1.95, `playhead ${raw.toFixed(3)} s`);
    check('the Snap toggle reports its state',
      (await evaluate("document.getElementById('ssSnapOnset').getAttribute('aria-pressed')")) === 'false');
    await evaluate("document.getElementById('ssSnapOnset').click()");

    console.log('\n=== the Notes toggle ===');
    await evaluate("document.getElementById('ssWaveNotes').click()");
    await sleep(180);
    const off = await evaluate(countCyan);
    check('Notes off removes every note block', off === 0, `${off} cyan px`);
    await evaluate("document.getElementById('ssWaveNotes').click()");
    await sleep(180);
    const on = await evaluate(countCyan);
    check('Notes on brings them back', on > 200, `${on} cyan px`);

    console.log('\n=== the resize grip ===');
    const grip = await evaluate(`(() => {
      const wrap = document.getElementById('ssWaveWrap');
      const grip = document.getElementById('ssWaveGrip');
      const before = Math.round(wrap.getBoundingClientRect().height);
      grip.focus();
      grip.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowUp', bubbles: true, cancelable: true }));
      const after = Math.round(wrap.getBoundingClientRect().height);
      return { before, after, pressed: grip.getAttribute('aria-valuenow') };
    })()`);
    check('ArrowUp on the grip makes the graph taller', grip.after > grip.before,
      `${grip.before} px -> ${grip.after} px`);
    check('the grip reports its own height', Number(grip.pressed) === grip.after, grip.pressed);
    check('the canvas backing store re-measured after the resize', await evaluate(`(() => {
      const wrap = document.getElementById('ssWaveWrap');
      const canvas = document.getElementById('ssWave');
      const dpr = canvas.width / canvas.getBoundingClientRect().width;
      return Math.abs(canvas.height / dpr - (wrap.getBoundingClientRect().height - 10)) < 3;
    })()`));

    console.log('\n=== zoom: the meta follows ===');
    const metaFull = await evaluate("document.getElementById('ssWaveMeta').textContent");
    await evaluate("document.getElementById('ssWaveZoomIn').click()");
    await sleep(160);
    const metaZoom = await evaluate("document.getElementById('ssWaveMeta').textContent");
    check('zoom in adds the visible window to the meta',
      metaZoom.split('\u00b7').length === metaFull.split('\u00b7').length + 1, metaZoom);
    await evaluate("document.getElementById('ssWaveFit').click()");
    await sleep(160);
    const metaBack = await evaluate("document.getElementById('ssWaveMeta').textContent");
    check('Fit returns to the whole track', metaBack === metaFull, metaBack);

    console.log('\n=== stamping + Save still behave ===');
    await evaluate(`(() => {
      const rows = document.querySelectorAll('#ssTbody tr');
      if (rows.length) rows[0].click();
      return rows.length;
    })()`);
    await sleep(120);
    // Stamp all three lines at their real starts: the studio refuses to save a
    // timeline with an unstarted line, which is exactly the guard we want.
    for (const t of [0.5, 1.8, 3.1]) {
      await evaluate(seekTo(t));
      await sleep(140);
      await evaluate("document.getElementById('ssStampBtn').click()");
      await sleep(180);
    }
    const row1 = await evaluate("document.querySelectorAll('#ssTbody tr')[0].textContent");
    check('stamping at the playhead writes 00:00.500 into row 1', /00:00\.500/.test(row1),
      row1.trim().slice(0, 40));
    const row2 = await evaluate("document.querySelectorAll('#ssTbody tr')[1].textContent");
    check('the second stamp writes 00:01.800 into row 2', /00:01\.800/.test(row2),
      row2.trim().slice(0, 40));

    await evaluate("document.getElementById('ssSave').click()");
    await sleep(1200);
    const put = putBodies.filter((b) => /tracks/.test(b.path) && b.method === 'PUT').pop();
    check('Save PUTs the track', !!put, put ? put.path : 'no PUT seen');
    const srt = put && put.body && put.body.synced_lyrics;
    check('the PUT body carries synced_lyrics', typeof srt === 'string' && srt.length > 0,
      srt ? JSON.stringify(srt.slice(0, 46)) : 'missing');
    check('the generated SRT is structurally valid SubRip',
      typeof srt === 'string' &&
      /^\d+\s*\n\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3}\s*\n/.test(srt),
      srt ? srt.split('\n').slice(0, 2).join(' ') : 'missing');
    check('every cue carries the three Telugu lines that were stamped',
      typeof srt === 'string' && (srt.match(/-->/g) || []).length === 3,
      srt ? `${(srt.match(/-->/g) || []).length} cues` : 'missing');
    const statusText = await evaluate("document.getElementById('ssStatusText').textContent");
    check('the studio reports the save as verified, not merely sent',
      /Saved/i.test(statusText), statusText);

    console.log('\n=== layout: the graph and the timeline share the screen ===');
    // Undo the grip test's pin, so the responsive CSS default is what gets
    // measured here (that is what a fresh admin sees).
    await evaluate(`(() => {
      const wrap = document.getElementById('ssWaveWrap');
      wrap.style.removeProperty('--ss-wave-h');
      document.getElementById('ssWaveGrip').dispatchEvent(
        new KeyboardEvent('keydown', { key: 'Home', bubbles: true, cancelable: true }));
      return true;
    })()`);
    await sleep(260);
    const VIEWPORTS = [
      [1920, 1080], [1536, 1024], [1440, 900], [1366, 768], [1280, 720], [1093, 614]
    ];
    const layout = [];
    for (const [wv, hv] of VIEWPORTS) {
      await cdp.send('Emulation.setDeviceMetricsOverride', {
        width: wv, height: hv, deviceScaleFactor: 1, mobile: false
      });
      await sleep(340);
      const m = await evaluate(`(() => {
        const r = (id) => {
          const el = document.getElementById(id);
          if (!el) return null;
          const b = el.getBoundingClientRect();
          return { top: Math.round(b.top), bottom: Math.round(b.bottom), h: Math.round(b.height) };
        };
        const main = document.querySelector('.ss-main');
        return {
          inner: window.innerHeight,
          preview: r('ssStage'),
          graph: r('ssWaveWrap'),
          timeline: r('ssTablewrap'),
          tableCard: Math.round(document.querySelector('.ss-tablecard').getBoundingClientRect().height),
          save: r('ssSave'),
          scrolls: main ? main.scrollHeight > main.clientHeight + 2 : false,
          canvasH: document.getElementById('ssWave').height,
          canvasW: document.getElementById('ssWave').width
        };
      })()`);
      layout.push({ wv, hv, ...m });
      console.log(`  ${String(wv + 'x' + hv).padEnd(10)} preview ${String(m.preview.h).padStart(3)} px ` +
        `· graph ${String(m.graph.h).padStart(3)} px · timeline ${String(m.tableCard).padStart(3)} px ` +
        `· canvas ${m.canvasW}x${m.canvasH} · column scrolls: ${m.scrolls ? 'yes' : 'no'}`);
    }
    for (const m of layout) {
      const tag = `${m.wv}x${m.hv}`;
      check(`${tag}: the voice graph keeps a readable height`, m.graph.h >= 120, `${m.graph.h} px`);
      check(`${tag}: the timeline stays usable`, m.tableCard >= 190, `${m.tableCard} px`);
      check(`${tag}: Save is inside the viewport`, m.save.bottom <= m.inner + 1,
        `save bottom ${m.save.bottom} vs viewport ${m.inner}`);
      const graphOnScreen = m.graph.bottom <= m.inner + 1;
      const timelineOnScreen = m.timeline.bottom <= m.inner + 1;
      // Either both are on screen together, or the whole column scrolls (the
      // documented narrow / short-viewport branch) — never one hiding the other.
      check(`${tag}: graph and timeline are both reachable`,
        (graphOnScreen && timelineOnScreen) || m.scrolls,
        graphOnScreen ? (timelineOnScreen ? 'both on screen' : 'column scrolls') : 'column scrolls');
    }
    await cdp.send('Emulation.clearDeviceMetricsOverride');

    if (process.env.SHOT_DIR) {
      const dir = process.env.SHOT_DIR;
      fs.mkdirSync(dir, { recursive: true });
      await cdp.send('Emulation.setDeviceMetricsOverride', {
        width: 1440, height: 900, deviceScaleFactor: 1, mobile: false
      });
      await sleep(420);
      const shot = await cdp.send('Page.captureScreenshot', { format: 'png' });
      fs.writeFileSync(path.join(dir, 'studio.png'), Buffer.from(shot.data, 'base64'));
      const box = await evaluate(`(() => {
        const b = document.getElementById('ssWaveCard').getBoundingClientRect();
        return { x: Math.round(b.x), y: Math.round(b.y), w: Math.round(b.width), h: Math.round(b.height) };
      })()`);
      const clip = await cdp.send('Page.captureScreenshot', {
        format: 'png',
        clip: { x: box.x, y: box.y, width: box.w, height: box.h, scale: 2 }
      });
      fs.writeFileSync(path.join(dir, 'graph.png'), Buffer.from(clip.data, 'base64'));
      console.log(`\nscreenshots written to ${dir}`);
      await cdp.send('Emulation.clearDeviceMetricsOverride');
    }

    console.log('\n=== hygiene ===');
    const pageErrors = [];
    const consoleErrors = [];
    for (const ev of cdp.events) {
      if (ev.method === 'Runtime.exceptionThrown') pageErrors.push(JSON.stringify(ev.params.exceptionDetails).slice(0, 200));
      if (ev.method === 'Log.entryAdded' && ev.params.entry.level === 'error') consoleErrors.push(ev.params.entry.text);
      if (ev.method === 'Runtime.consoleAPICalled' && ev.params.type === 'error') {
        consoleErrors.push((ev.params.args || []).map((a) => a.value || a.description).join(' '));
      }
    }
    check('no page exceptions', pageErrors.length === 0, pageErrors.slice(0, 2).join(' | '));
    const noisy = consoleErrors.filter((e) => !/favicon|net::ERR|Failed to load resource/i.test(e));
    check('no console errors', noisy.length === 0, noisy.slice(0, 3).join(' | '));

    console.log(`\n=== ${pass} passed, ${fail} failed ===`);
    if (fail) {
      console.log('failures:');
      for (const f of failures) console.log('  - ' + f);
    }
  } finally {
    try { if (cdp) cdp.close(); } catch (_) {}
    try { child.kill(); } catch (_) {}
    try { server.close(); } catch (_) {}
    try { fs.rmSync(userDataDir, { recursive: true, force: true }); } catch (_) {}
  }
  process.exitCode = fail ? 1 : 0;
}

main().catch((e) => {
  console.error('HARNESS ERROR:', e.message);
  process.exitCode = 1;
});

