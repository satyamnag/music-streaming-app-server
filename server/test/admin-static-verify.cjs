// Static verification of server/admin.html after the filter fixes.
const fs = require('fs');
const path = require('path');
const h = fs.readFileSync(path.join(__dirname, '..', 'admin.html'), 'utf8');

console.log('=== inline script syntax ===');
{
  const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
  let m, i = 0, ok = true;
  while ((m = re.exec(h))) {
    i++;
    if (!m[1].trim()) continue;
    try { new Function(m[1]); console.log('block ' + i + ': OK (' + m[1].length + ' chars)'); }
    catch (e) { ok = false; console.log('block ' + i + ': SYNTAX ERROR -> ' + e.message); }
  }
  console.log(ok ? 'ALL BLOCKS PARSE' : 'FAILURES PRESENT');
}

console.log('\n=== duplicate element ids ===');
{
  const ids = Array.from(h.matchAll(/\sid="([^"]+)"/g), (m) => m[1]);
  const seen = new Set(), dup = new Set();
  for (const id of ids) { if (seen.has(id)) dup.add(id); seen.add(id); }
  console.log(dup.size ? 'DUPLICATE IDS: ' + Array.from(dup).join(', ')
                       : 'no duplicate ids (' + ids.length + ' total)');
}

console.log('\n=== filter row <th> cell alignment ===');
{
  const rows = Array.from(h.matchAll(/<tr class="filter-row">([\s\S]*?)<\/tr>/g));
  const body = rows[0][1];
  const cells = body.split(/<\/th>/).filter((s) => s.trim());
  console.log('filter-row cells: ' + cells.length);
  cells.forEach((c, i) => {
    const found = c.match(/id="([^"]+)"/g) || ['(empty)'];
    console.log('  col' + (i + 1) + ': ' + found.join(', '));
  });
  const headerRow = /<table><thead><tr>([\s\S]*?)<\/tr>/.exec(h);
  if (headerRow) {
    const heads = headerRow[1].split(/<\/th>/).filter((s) => s.trim());
    console.log('header cells: ' + heads.length);
  }
}

console.log('\n=== filter state variables vs markup ===');
{
  const vars = ['filterArtist', 'filterAlbum', 'filterLanguage', 'filterStatus',
                'filterSync', 'filterKaraoke', 'filterRingtone', 'filterDurMin', 'filterDurMax'];
  for (const v of vars) {
    const inMarkup = new RegExp('id="' + v + '"').test(h);
    const readGuarded = new RegExp("(getElementById\\('" + v + "'\\)[\\s\\S]{0,40}if\\s*\\(|val\\('" + v + "'\\))").test(h);
    console.log(`${v.padEnd(16)} markup=${inMarkup ? 'yes' : 'NO '}  read-safely=${readGuarded ? 'yes' : 'unknown'}`);
  }
}

console.log('\n=== file size ===');
console.log(fs.statSync(path.join(__dirname, '..', 'admin.html')).size + ' bytes');
