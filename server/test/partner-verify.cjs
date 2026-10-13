// Focused structural verification for the Partner Program additions to
// admin.html and partner.html. Run: node test/partner-verify.cjs
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..');
let failures = 0;

function ok(cond, label) {
  console.log((cond ? '  PASS ' : '  FAIL ') + label);
  if (!cond) failures++;
}

console.log('=== admin.html: markup id uniqueness (partner additions) ===');
{
  const h = fs.readFileSync(path.join(dir, 'admin.html'), 'utf8');
  const scriptStart = h.indexOf('<script');
  const markup = h.slice(0, scriptStart);

  const ids = Array.from(markup.matchAll(/\sid="([^"]+)"/g), (m) => m[1]);
  const seen = new Set();
  const dup = new Set();
  for (const id of ids) {
    if (seen.has(id)) dup.add(id);
    seen.add(id);
  }
  ok(dup.size === 0, 'no duplicate ids in markup (' + ids.length + ' ids)');
  if (dup.size) console.log('       duplicates: ' + Array.from(dup).join(', '));

  const expected = [
    'nav-partners', 'partnersPanel', 'partnerStats', 'partnerStatusFilter',
    'partnerTbody', 'partnerModal', 'pmTitle', 'pmSubtitle', 'pmNotice',
    'pmBody', 'pmActions', 'pmAudit',
  ];
  for (const id of expected) {
    const n = (markup.match(new RegExp('id="' + id + '"', 'g')) || []).length;
    ok(n === 1, 'id "' + id + '" appears exactly once (found ' + n + ')');
  }
}

console.log('\n=== admin.html: partner JS wiring ===');
{
  const h = fs.readFileSync(path.join(dir, 'admin.html'), 'utf8');
  const checks = [
    [/'partners'\)\s*\{\s*loadPartners\(\)/, "showView('partners') calls loadPartners()"],
    [/currentView === 'partners'/, 'refreshCurrent handles partners view'],
    [/async function loadPartners/, 'loadPartners defined'],
    [/async function openPartner/, 'openPartner defined'],
    [/async function approvePartner/, 'approvePartner defined'],
    [/async function partnerDecision/, 'partnerDecision defined'],
    [/async function reviewPartnerDoc/, 'reviewPartnerDoc defined'],
    [/async function viewPartnerDoc/, 'viewPartnerDoc defined'],
    [/function renderPartnerAudit/, 'renderPartnerAudit defined'],
    [/Aadhaar Act 2016 s\.8A\(4\)\(b\)/, 'Aadhaar prohibition documented for reviewers'],
  ];
  for (const [re, label] of checks) ok(re.test(h), label);

  // All partner-facing function names referenced in onclick handlers must exist.
  // Note: `onclick="if(...)fn()"` is an existing pattern in this file (modal
  // backdrop dismissal), so a leading `if(` is excluded rather than treated
  // as a missing function.
  const declared = new Set(
    Array.from(h.matchAll(/(?:async\s+)?function\s+([A-Za-z_$][\w$]*)/g), (m) => m[1]),
  );
  const called = new Set(
    Array.from(h.matchAll(/onclick="([A-Za-z_$][\w$]*)\(/g), (m) => m[1])
      .filter((fn) => fn !== 'if'),
  );
  const missing = Array.from(called).filter((f) => !declared.has(f));
  ok(missing.length === 0, 'every onclick handler exists' +
    (missing.length ? ' (missing: ' + missing.join(', ') + ')' : ''));
}

console.log('\n=== partner.html: structure and safety ===');
{
  const p = fs.readFileSync(path.join(dir, 'partner.html'), 'utf8');

  ok(/<meta name="referrer" content="no-referrer">/.test(p),
    'referrer policy is no-referrer (the verification link carries a token)');
  ok(/<meta name="robots" content="noindex, nofollow">/.test(p),
    'portal is not indexable');

  // The public page must not reference admin routes.
  ok(!/\/api\/admin\//.test(p), 'portal never calls an /api/admin/* route');

  // Only the QR image may put the token in a URL; nothing else may.
  const tokenInUrl = Array.from(p.matchAll(/'[^']*\?token='/g)).length;
  ok(tokenInUrl <= 1, 'token appears in a URL at most once (QR img only); found ' + tokenInUrl);

  // No third-party origins should be loaded. Placeholder text in input
  // attributes (e.g. placeholder="https://…") is not a loaded origin, so
  // only real markup attributes that fetch are considered.
  const loadable = Array.from(
    p.matchAll(/<(?:script|link|img|iframe|source)\b[^>]*\b(?:src|href)="(https?:\/\/[^"]+)"/gi),
    (m) => m[1],
  ).filter((u) => !u.startsWith('https://play.google.com'));
  ok(loadable.length === 0, 'no external resources loaded' +
    (loadable.length ? ' (found: ' + Array.from(new Set(loadable)).join(', ') + ')' : ''));

  // Aadhaar must be explicitly refused in the UI copy.
  ok(/do not accept Aadhaar/i.test(p), 'portal states Aadhaar is not accepted');

  // Key flows present.
  const flows = [
    [/\/api\/partner\/register/, 'register call'],
    [/\/api\/partner\/resend-verification/, 'resend verification call'],
    [/\/api\/partner\/draft/, 'draft save call'],
    [/\/api\/partner\/documents/, 'document upload call'],
    [/\/api\/partner\/submit/, 'submit call'],
    [/\/api\/partner\/me/, 'self fetch call'],
    [/\/api\/partner\/consent/, 'consent call'],
  ];
  for (const [re, label] of flows) ok(re.test(p), label);

  // Every onclick handler referenced must be declared.
  const declared = new Set(
    Array.from(p.matchAll(/(?:async\s+)?function\s+([A-Za-z_$][\w$]*)/g), (m) => m[1]),
  );
  const called = new Set(
    Array.from(p.matchAll(/onclick="([A-Za-z_$][\w$]*)\(/g), (m) => m[1]),
  );
  const missing = Array.from(called).filter((f) => !declared.has(f));
  ok(missing.length === 0, 'every onclick handler exists' +
    (missing.length ? ' (missing: ' + missing.join(', ') + ')' : ''));
}

console.log('\n=== inline script syntax ===');
{
  for (const file of ['admin.html', 'partner.html']) {
    const h = fs.readFileSync(path.join(dir, file), 'utf8');
    const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi;
    let m;
    let i = 0;
    let bad = null;
    while ((m = re.exec(h))) {
      i++;
      if (!m[1].trim()) continue;
      try { new Function(m[1]); } catch (e) { bad = 'block ' + i + ': ' + e.message; }
    }
    ok(!bad, file + ' inline script parses (' + i + ' block(s))' + (bad ? ' -> ' + bad : ''));
  }
}

console.log('\n' + (failures === 0 ? 'ALL CHECKS PASSED' : failures + ' CHECK(S) FAILED'));
process.exit(failures === 0 ? 0 : 1);
