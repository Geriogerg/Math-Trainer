// Preview smoke test (Phase 1 commit 8): a fresh browser plays the deployed
// app like a new visitor, then deletes the account it created.
//
//   node tool/smoke/preview_smoke.mjs <app url> [chrome executable]
//
// SMOKE_NETWORK=slow4g (or fast4g) emulates that network with an empty
// cache — the plan's exit test: the first question within 30 s on slow 4G
// from a fresh browser. The times are printed either way.
// SMOKE_TRACE=1 also prints every request up to the first question (start,
// end, path without its query) — where the first-load time goes — and,
// live, every write to another origin (upload, RPC) with its status and,
// on an error, the response body.
//
// Steps, each failing loudly with a screenshot (smoke-failure.png):
//   1. fresh profile → an anonymous player is created (no form);
//   2. Home: the default Basics selection's first game (a game from level
//      0 since the Levels phase — no placement) is played to its result
//      screen — every answer typed at once ("1", Enter), so the
//      per-question timeout (always on in a release build) never fires;
//   3. reload with the session about to expire → the page refreshes it
//      while the files download (Phase 5.1), same player; Profile shows the
//      game's answers (history survived); the game scheduled sounds
//      (Phase 5: on by default);
//   4. "Delete my data" → the account is deleted (cleans up after itself:
//      anonymous sign-ins are rate-limited per IP, and the project must not
//      fill with test players).
//
// SMOKE_READ_ONLY=1 (production since Phase 5.2, where tests must leave no
// trace): every request that could write — anything but GET, HEAD and
// OPTIONS to another origin than the site — is blocked by the browser, but
// one: the guest's sign-up is answered by the script itself with a made-up
// session (Phase 6c commit 6: once the gate is gone, a stranger's first
// screen is Home, and reaching it creates a guest — never on production).
// The robot check is answered alike (no real token is needed for a sign-up
// that never leaves the browser). The visit stops at the first screen (the
// beta gate, or Home) after opening both legal pages in English and French
// from it (the gate's links, or Profile's) and checking the site is
// installable. SMOKE_EXPECT_VERSION=<short sha> also checks the site serves
// that build.
//
// The full visit (staging), once its guest is deleted, signs in to a
// confirmed account kept for the test (SMOKE_DUEL_EMAIL and
// SMOKE_DUEL_PASSWORD, CI secrets), plays a rated Basics duel and signs out
// (Phase 6c commit 6; review M12). Without them: a warning, no duel.
//
// The app draws on a canvas: the script turns Flutter's accessibility tree
// on and finds widgets by their text in that DOM. Only Node (>= 22, global
// WebSocket) and Chrome — nothing to install.
import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [appUrl, chromePath = 'google-chrome'] = process.argv.slice(2);
if (!appUrl) {
  console.error('usage: node preview_smoke.mjs <app url> [chrome]');
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/// On GitHub Actions the reason also becomes an annotation: job logs need
/// a signed-in reader, annotations are public (doc/progress.md, Phase 3a).
function annotate(message) {
  if (!process.env.GITHUB_ACTIONS) return;
  const escaped = message.replace(/%/g, '%25').replace(/\r/g, '%0D').replace(/\n/g, '%0A');
  console.log(`::error title=Smoke test::${escaped}`);
}
// Anything thrown outside fail() (browser not starting, DevTools errors).
for (const event of ['uncaughtException', 'unhandledRejection']) {
  process.on(event, (error) => {
    console.error(error);
    annotate(`crashed: ${error?.message ?? error}`);
    process.exit(1);
  });
}

const profileDir = mkdtempSync(join(tmpdir(), 'mt-smoke-'));

// --- browser ---------------------------------------------------------------
const chrome = spawn(
  chromePath,
  [
    '--headless=new',
    '--remote-debugging-port=0',
    `--user-data-dir=${profileDir}`,
    '--no-first-run',
    '--disable-extensions',
    '--window-size=412,800',
    'about:blank',
  ],
  { stdio: ['ignore', 'ignore', 'pipe'] },
);
// Chrome prints its DevTools address; Edge on Windows only writes it to
// the profile's DevToolsActivePort (Phase 6c commit 6: the smoke run
// locally): either.
const port = await new Promise((resolve, reject) => {
  let buffer = '';
  chrome.stderr.on('data', (chunk) => {
    buffer += chunk;
    const m = buffer.match(/DevTools listening on ws:\/\/[^:]+:(\d+)/);
    if (m) resolve(m[1]);
  });
  const poll = setInterval(() => {
    try {
      const first = readFileSync(join(profileDir, 'DevToolsActivePort'), 'utf8').split(/\r?\n/)[0].trim();
      if (first) {
        clearInterval(poll);
        resolve(first);
      }
    } catch (_) {
      // Not written yet.
    }
  }, 200);
  chrome.on('exit', (code) => reject(new Error(`chrome exited (${code})`)));
  setTimeout(() => {
    clearInterval(poll);
    reject(new Error('chrome did not start'));
  }, 30000);
});
const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const page = targets.find((t) => t.type === 'page' && /^(https?:|about:)/.test(t.url));
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let nextId = 1;
const pending = new Map();
const consoleErrors = [];

// --- request waterfall (SMOKE_TRACE=1) ---------------------------------------
const trace = process.env.SMOKE_TRACE === '1';
const requests = new Map();
function traceEvent(method, p) {
  if (method === 'Network.requestWillBeSent') {
    const url = new URL(p.request.url);
    if (!/^https?:$/.test(url.protocol)) return;
    // The path only: queries carry tokens and keys, never printed.
    const where = url.origin === new URL(appUrl).origin ? '' : url.hostname.split('.')[0] + ':';
    requests.set(p.requestId, {
      name: `${p.request.method} ${where}${url.pathname}`,
      start: Date.now(),
      end: null,
      // Writes to another origin (uploads, sign-ins, RPCs): printed live
      // with their status, at any point of the visit.
      api: where !== '' && p.request.method !== 'GET',
    });
  } else if (method === 'Network.responseReceived') {
    const r = requests.get(p.requestId);
    if (r) r.status = p.response.status;
  } else if (method === 'Network.loadingFinished' || method === 'Network.loadingFailed') {
    const r = requests.get(p.requestId);
    if (r && r.end === null) {
      r.end = Date.now();
      r.bytes = p.encodedDataLength ?? 0;
      r.failed = method === 'Network.loadingFailed';
      if (r.api && r.name.split(' ')[0] !== 'OPTIONS') traceApi(p.requestId, r, p.errorText);
    }
  }
}
/// One API call: status, and the body of an error answer (the server's
/// JSON errors name the reason; never a token — responses carry none
/// except sign-ins, whose bodies are not printed).
async function traceApi(requestId, r, errorText) {
  const at = ((r.end - started) / 1000).toFixed(1);
  let line = `  [api ${at} s] ${r.name} → ${r.failed ? `failed (${errorText})` : r.status}`;
  if (!r.failed && r.status >= 400 && !r.name.includes('/auth/')) {
    try {
      const { body } = await send('Network.getResponseBody', { requestId });
      line += ` ${body.slice(0, 300)}`;
    } catch (_) {}
  }
  console.log(line);
}
function printWaterfall(until) {
  const s = (t) => ((t - started) / 1000).toFixed(1).padStart(5);
  console.log('  requests (s from navigation: start → end, KB on the wire):');
  for (const r of [...requests.values()].sort((a, b) => a.start - b.start)) {
    if (r.start > until) continue;
    const end = r.end === null ? '    …' : s(r.end);
    const kb = r.end === null ? '' : `${(r.bytes / 1024).toFixed(1).padStart(7)}${r.failed ? ' failed' : ''}`;
    console.log(`  ${s(r.start)} → ${end} ${kb}  ${r.name}`);
  }
}
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  } else if (msg.method === 'Fetch.requestPaused') {
    guardWrite(msg.params);
  } else if (msg.method?.startsWith('Network.') && trace) {
    traceEvent(msg.method, msg.params);
  } else if (msg.method === 'Runtime.exceptionThrown') {
    consoleErrors.push(msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text);
  }
});
// --- read-only mode (SMOKE_READ_ONLY=1) -------------------------------------
const readOnly = process.env.SMOKE_READ_ONLY === '1';
const blockedWrites = [];
let fakedSignUps = 0;
const base64url = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
/// A guest's session as Supabase would answer a sign-up — made up here,
/// never sent anywhere: its token is not signed, so any later call with it
/// is refused by the project (the app takes that as being offline).
function fakeSession() {
  const id = '00000000-0000-4000-8000-' + Date.now().toString(16).padStart(12, '0').slice(-12);
  const expiresAt = Math.floor(Date.now() / 1000) + 3600;
  const token = [base64url({ alg: 'none' }), base64url({ sub: id, exp: expiresAt, role: 'authenticated', is_anonymous: true }), 'smoke'].join('.');
  const now = new Date().toISOString();
  return {
    access_token: token,
    token_type: 'bearer',
    expires_in: 3600,
    expires_at: expiresAt,
    refresh_token: 'smoke-' + id,
    user: { id, aud: 'authenticated', role: 'authenticated', email: '', is_anonymous: true, app_metadata: {}, user_metadata: {}, identities: [], created_at: now, updated_at: now },
  };
}
function guardWrite({ requestId, request }) {
  const url = new URL(request.url);
  const write = !['GET', 'HEAD', 'OPTIONS'].includes(request.method);
  if (write && url.origin !== new URL(appUrl).origin && url.pathname === '/auth/v1/signup') {
    fakedSignUps++;
    send('Fetch.fulfillRequest', {
      requestId,
      responseCode: 200,
      responseHeaders: [
        { name: 'content-type', value: 'application/json' },
        { name: 'access-control-allow-origin', value: request.headers.Origin || request.headers.origin || new URL(appUrl).origin },
      ],
      body: Buffer.from(JSON.stringify(fakeSession())).toString('base64'),
    }).catch(() => {});
  } else if (write && url.origin !== new URL(appUrl).origin) {
    // The path only: queries may carry keys.
    blockedWrites.push(`${request.method} ${url.hostname.split('.')[0]}:${url.pathname}`);
    send('Fetch.failRequest', { requestId, errorReason: 'BlockedByClient' }).catch(() => {});
  } else {
    send('Fetch.continueRequest', { requestId }).catch(() => {});
  }
}

const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const id = nextId++;
    pending.set(id, (m) => (m.error ? reject(new Error(JSON.stringify(m.error))) : resolve(m.result)));
    ws.send(JSON.stringify({ id, method, params }));
  });
const evaluate = async (expression) =>
  (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result?.value;

await send('Page.enable');
await send('Runtime.enable');
if (readOnly) {
  await send('Fetch.enable', { patterns: [{ urlPattern: '*', requestStage: 'Request' }] });
  // The page's robot check answers at once (Phase 6c commit 3): the sign-up
  // it would protect is answered by this script.
  await send('Page.addScriptToEvaluateOnNewDocument', {
    source: `Object.defineProperty(window, 'mtHumanCheck', {
      value: () => Promise.resolve('smoke-read-only'),
      writable: false,
      configurable: false,
    });`,
  });
  console.log('read-only: writes to other origins are blocked, the guest is made up');
}
// Sound (Phase 5): count the tones the page schedules. Every answer plays
// one (on by default); a game with none means the audio never unlocked or
// the Web Audio code broke.
await send('Page.addScriptToEvaluateOnNewDocument', {
  source: `(() => {
    window.__mathTrainerTones = 0;
    const AC = window.AudioContext;
    if (!AC) return;
    const create = AC.prototype.createOscillator;
    AC.prototype.createOscillator = function () {
      window.__mathTrainerTones++;
      return create.apply(this, arguments);
    };
  })();`,
});
await send('Emulation.setDeviceMetricsOverride', { width: 412, height: 800, deviceScaleFactor: 1, mobile: false });
// Same profiles as the first-load measurements (doc/architecture.md).
const networks = {
  fast4g: { latency: 60, downloadThroughput: (9000 * 1024) / 8, uploadThroughput: (1500 * 1024) / 8 },
  slow4g: { latency: 150, downloadThroughput: (1600 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 },
};
const network = networks[process.env.SMOKE_NETWORK ?? ''];
if (network || trace) await send('Network.enable');
if (network) {
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  await send('Network.emulateNetworkConditions', { offline: false, ...network });
  console.log(`network: ${process.env.SMOKE_NETWORK}, cache disabled`);
}

// --- helpers ---------------------------------------------------------------
// True from typing SMOKE_BETA_CODE until Home replaces the gate (and while
// the duel account's address is typed). The failure screenshot is uploaded
// as a CI artifact, and GitHub masks secrets in logs, not in images: no
// screenshot while the code may be on screen.
let codeOnScreen = false;
async function fail(message) {
  if (codeOnScreen) {
    console.error('screenshot withheld: the invitation code may be on screen');
  } else {
    try {
      const { data } = await send('Page.captureScreenshot', { format: 'png' });
      writeFileSync('smoke-failure.png', Buffer.from(data, 'base64'));
    } catch (_) {}
  }
  console.error(`SMOKE FAILED: ${message}`);
  if (consoleErrors.length) console.error('page exceptions:\n  ' + consoleErrors.join('\n  '));
  annotate(message + (consoleErrors.length ? `\npage exceptions: ${consoleErrors.slice(0, 3).join(' | ')}` : ''));
  await shutdown(1);
}

async function shutdown(code) {
  try { ws.close(); } catch (_) {}
  chrome.kill();
  await sleep(500);
  try { rmSync(profileDir, { recursive: true, force: true }); } catch (_) {}
  process.exit(code);
}

/// Flutter builds its accessibility DOM only when asked; the placeholder
/// button is how a screen reader asks. Re-armed after every reload. Up to
/// 60 s: on emulated slow 4G Flutter alone takes about 20 s to start.
async function enableSemantics() {
  for (let i = 0; i < 120; i++) {
    const done = await evaluate(`(() => {
      if (document.querySelector('flt-semantics')) return true;
      const p = document.querySelector('flt-semantics-placeholder');
      if (p) p.click();
      return false;
    })()`);
    if (done) return;
    await sleep(500);
  }
  await fail('accessibility tree never appeared');
}

/// The smallest visible semantics node whose label or text contains
/// [text] (equals it, with [exact]): its centre, or null.
const findText = (text, exact = false) =>
  evaluate(`(() => {
    const want = ${JSON.stringify(text)};
    const exact = ${exact};
    let best = null;
    for (const el of document.querySelectorAll('flt-semantics, flt-semantics *')) {
      const labels = [el.getAttribute('aria-label') || '', el.textContent || ''].map((t) => t.trim());
      if (!labels.some((t) => (exact ? t === want : t.includes(want)))) continue;
      const r = el.getBoundingClientRect();
      if (r.width === 0 || r.height === 0) continue;
      // Its centre must be on screen and on top there: a node half under
      // the bottom edge (a long Profile) would take a click that lands
      // nowhere — keep scrolling instead.
      const x = r.left + r.width / 2;
      const y = r.top + r.height / 2;
      if (y <= 0 || y >= innerHeight || x <= 0 || x >= innerWidth) continue;
      const top = document.elementFromPoint(x, y);
      if (top && !el.contains(top) && !top.contains(el)) continue;
      if (!best || r.width * r.height < best.area) {
        best = { x, y, area: r.width * r.height };
      }
    }
    return best;
  })()`);

async function waitForText(text, timeoutMs = 30000, { exact = false, scroll = false } = {}) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const hit = await findText(text, exact);
    if (hit) return hit;
    // A long screen builds its accessibility nodes as they scroll in.
    if (scroll) {
      await send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 206, y: 400, deltaX: 0, deltaY: 400 });
    }
    await sleep(300);
  }
  await fail(`"${text}" never appeared`);
}

/// Like waitForText, for a regular expression ([source]) in any node's label
/// or text.
async function waitForPattern(source, timeoutMs = 30000) {
  const end = Date.now() + timeoutMs;
  while (Date.now() < end) {
    const hit = await evaluate(`(() => {
      const re = new RegExp(${JSON.stringify(source)});
      for (const el of document.querySelectorAll('flt-semantics, flt-semantics *')) {
        for (const t of [el.getAttribute('aria-label') || '', el.textContent || '']) {
          if (re.test(t)) return true;
        }
      }
      return false;
    })()`);
    if (hit) return;
    await sleep(300);
  }
  await fail(`nothing matching /${source}/ appeared`);
}

async function click({ x, y }) {
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
    await sleep(30);
  }
}

async function tapText(text, timeoutMs, options) {
  await click(await waitForText(text, timeoutMs, options));
}

async function pressKey(key) {
  const isDigit = /^[0-9]$/.test(key);
  const vk = isDigit ? key.charCodeAt(0) : 13;
  const base = { key, code: isDigit ? `Digit${key}` : key, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk };
  await send('Input.dispatchKeyEvent', { type: isDigit ? 'keyDown' : 'rawKeyDown', ...base, ...(isDigit ? { text: key } : {}) });
  if (!isDigit) await send('Input.dispatchKeyEvent', { type: 'char', ...base, text: '\r' });
  await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
}

const guestId = () =>
  evaluate(`(() => {
    const k = Object.keys(localStorage).find((k) => k.endsWith('-auth-token'));
    if (!k) return null;
    const u = JSON.parse(localStorage.getItem(k)).user;
    return u && u.is_anonymous ? u.id : null;
  })()`);

/// The read-only visit ends at the first screen: it rendered, the site is
/// installable, the build is the expected one, nothing was written.
/// Both legal pages from the links on screen, each in English then French
/// (Phase 6c commit 2; the exit of 6c: "finds the legal pages in both
/// languages"), back to where it started.
async function checkLegalPages(where) {
  for (const [link, english, french] of [
    ['Privacy policy', 'Who is responsible', 'Responsable du traitement'],
    ['Legal notice', 'Publisher', 'Éditeur'],
  ]) {
    await tapText(link, 30000, { exact: true, scroll: true });
    // It opens in the browser's language: each one by its switch.
    await tapText('English', 30000, { exact: true });
    await waitForText(english, 10000, { exact: true });
    await tapText('Français', 10000, { exact: true });
    await waitForText(french, 10000, { exact: true });
    await tapText('Back', 10000, { exact: true });
    await sleep(600);
  }
  console.log(`  legal pages, English and French, from ${where}: shown`);
}

async function readOnlyEnd(gate) {
  const shown = gate || (await findText('Play Basics'));
  if (!shown) await fail('no first screen (beta gate or Home) within 60 s');
  console.log(`  first screen: ${gate ? 'beta gate' : 'Home'} (${((Date.now() - started) / 1000).toFixed(1)} s from navigation)`);
  if (gate) {
    await checkLegalPages('the gate');
  } else {
    await tapText('Profile', 30000, { exact: true });
    await checkLegalPages('Profile');
  }
  const { installabilityErrors = [] } = await send('Page.getInstallabilityErrors');
  if (installabilityErrors.length) {
    await fail(`not installable: ${installabilityErrors.map((e) => e.errorId).join(', ')}`);
  }
  console.log('  installable: yes');
  const want = process.env.SMOKE_EXPECT_VERSION;
  if (want) {
    // As the string literal the compiler wrote ("f40ece0"): bare, seven hex
    // characters can occur anywhere in 3 MB of code.
    // The app's code is main.<hash>.dart.js (Phase 6a): its name is in
    // flutter_bootstrap.js.
    const has = await evaluate(`fetch('flutter_bootstrap.js', { cache: 'no-store' }).then((r) => r.text()).then((b) => (b.match(/"mainJsPath":"([^"]+)"/) || [])[1] || 'main.dart.js').then((main) => fetch(main, { cache: 'no-store' })).then((r) => r.text()).then((t) => t.includes(${JSON.stringify(JSON.stringify(want))}))`);
    if (!has) await fail(`the site does not serve build ${want}`);
    console.log(`  build ${want}: served`);
  }
  if (consoleErrors.length) await fail('page exceptions');
  console.log(`  writes blocked: ${blockedWrites.length ? blockedWrites.join(', ') : 'none attempted'}; sign-ups made up: ${fakedSignUps}`);
  console.log(`SMOKE PASSED (read-only) in ${Math.round((Date.now() - started) / 1000)} s`);
  await shutdown(0);
}

// --- the visit -------------------------------------------------------------
const step = (s) => console.log(`- ${s}`);
const started = Date.now();

step(`open ${appUrl} in a fresh browser`);
await send('Page.navigate', { url: appUrl });
await enableSemantics();

// The invite-only beta's gate (Phase 3a commit 3), when the build has it:
// the code comes from SMOKE_BETA_CODE (a CI secret). The test account it
// creates is deleted at the end, which frees the code's use.
{
  const end = Date.now() + 60000;
  let gate = false;
  while (Date.now() < end) {
    if (await findText('Play Basics')) break;
    if (await findText('Invitation code')) {
      gate = true;
      break;
    }
    await sleep(300);
  }
  if (readOnly) await readOnlyEnd(gate);
  if (gate) {
    step(`beta gate shown (${((Date.now() - started) / 1000).toFixed(1)} s from navigation): enter the invitation code`);
    const code = process.env.SMOKE_BETA_CODE;
    if (!code) await fail('the build has the beta gate on, but SMOKE_BETA_CODE is not set');
    await tapText('Invitation code');
    codeOnScreen = true;
    await send('Input.insertText', { text: code });
    await tapText('Continue', 10000, { exact: true });
  }
}

step('a guest is created, no form: Home appears');
await waitForText('Play Basics', 60000);
codeOnScreen = false;
const id = await guestId();
if (!id) await fail('no anonymous session stored');
console.log(`  guest ${id} (${((Date.now() - started) / 1000).toFixed(1)} s from navigation)`);
// The page's early sign-in (Phase 5.1 commit 1): 'signed up' without a
// gate, 'gate' behind it, 'none' on a build without its settings.
const bootSignIn = () => evaluate('window.mtBootAuth');
console.log(`  page sign-in during the download: ${await bootSignIn()}`);

// Home screen (Phase 5 commit 7): the browser's own verdict on the web app
// manifest. Reported after the account is deleted, like the server.
let installProblem = null;
{
  const { installabilityErrors = [] } = await send('Page.getInstallabilityErrors');
  const errors = installabilityErrors.map((e) => e.errorId);
  console.log(`  installable: ${errors.length === 0 ? 'yes' : errors.join(', ')}`);
  if (errors.length > 0) installProblem = `not installable: ${errors.join(', ')}`;
}

step('Home: Play the default Basics selection, then Start');
// Home (Redesign phase): each row's Play opens the setup page; its
// accessible label names the row ("Play" alone is the title and a tab too).
await tapText('Play Basics', 30000, { exact: true });
await tapText('Start', 30000, { exact: true });
// Read the count from the "1 / N" counter (10 per operation by default).
let questions = null;
{
  const end = Date.now() + 30000;
  while (questions === null && Date.now() < end) {
    questions = await evaluate(`(() => {
      for (const el of document.querySelectorAll('flt-semantics, flt-semantics *')) {
        for (const t of [el.getAttribute('aria-label') || '', el.textContent || '']) {
          // Part of a longer label too (the counter shares its node).
          const m = t.match(/(?:^|[^0-9])1 \\/ (\\d+)(?:[^0-9]|$)/);
          if (m) return Number(m[1]);
        }
      }
      return null;
    })()`);
    if (questions === null) await sleep(300);
  }
  if (questions === null) await fail('no question counter "1 / N" appeared');
}
// Two taps (Play, Start) included: what a new visitor going
// straight to a game experiences, at script speed.
console.log(`  first question ${((Date.now() - started) / 1000).toFixed(1)} s from navigation (${questions} questions)`);
if (trace) printWaterfall(Date.now());

step(`answer the ${questions} questions`);
for (let q = 0; q < questions; q++) {
  await pressKey('1');
  await pressKey('Enter');
  await sleep(1600); // a wrong answer shows its correction for 1 s
}
{
  const end = Date.now() + 20000;
  let done = false;
  while (!done && Date.now() < end) {
    // "Game complete" since Phase 6b commit 7 (it was "Session complete").
    done = Boolean((await findText('Game complete')) || (await findText('Session complete')) || (await findText('Your starting levels')));
    if (!done) await sleep(300);
  }
  if (!done) await fail('neither "Game complete" nor "Your starting levels" appeared');
}

// Checked after the account is deleted, like the server (no guest left).
const tones = (await evaluate('window.__mathTrainerTones')) ?? 0;
console.log(`  ${tones} tones scheduled during the game`);
const soundProblem = tones > 0 ? null : 'no sound was scheduled during the game';

step('reload with the session about to expire: same guest, history kept');
// Its expiry moved to 30 s from now: the page must refresh it before the app
// starts (Phase 5.1 commit 1), and the player must stay the same.
await evaluate(`(() => {
  const k = Object.keys(localStorage).find((k) => k.endsWith('-auth-token'));
  const s = JSON.parse(localStorage.getItem(k));
  s.expires_at = Math.floor(Date.now() / 1000) + 30;
  localStorage.setItem(k, JSON.stringify(s));
})()`);
await send('Page.reload', {});
await enableSemantics();
{
  const outcome = await bootSignIn();
  console.log(`  page sign-in during the download: ${outcome}`);
  if (outcome === 'failed') await fail('the page could not refresh the session');
}
await tapText('Profile', 60000, { exact: true });
if ((await guestId()) !== id) await fail('a reload changed the player');
// An operation with answers shows its mean time: "1.2 s" since Phase 6b commit 7
// ("1234 ms" before — kept, for a deploy in between).
// No backslash in the pattern: it goes through a string, then the page.
await waitForPattern('([0-9][.][0-9] s|[0-9] ms)($|[^A-Za-z])');

// The whole online path, when the build has a server: the game is uploaded,
// the server replays and validates it, and only then writes the player's
// server levels (Phase 2). SMOKE_SUPABASE_URL / SMOKE_SUPABASE_KEY (the
// public key) let the script read them as the guest; a sleeping free
// server can take a minute to wake, and the app retries after 30 s.
// A failure here is reported after the account is deleted (no test guest
// left behind).
let serverProblem = null;
if (process.env.SMOKE_SUPABASE_URL && process.env.SMOKE_SUPABASE_KEY) {
  step('the game reached the server, which validated it');
  const token = await evaluate(`(() => {
    const k = Object.keys(localStorage).find((k) => k.endsWith('-auth-token'));
    return k ? JSON.parse(localStorage.getItem(k)).access_token : null;
  })()`);
  if (!token) await fail('no access token in the page');
  const end = Date.now() + 150000;
  let levels = {};
  while (Object.keys(levels).length === 0 && Date.now() < end) {
    try {
      const response = await fetch(`${process.env.SMOKE_SUPABASE_URL}/rest/v1/rpc/my_server_levels`, {
        method: 'POST',
        headers: {
          apikey: process.env.SMOKE_SUPABASE_KEY,
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        },
        body: '{}',
      });
      if (response.ok) levels = await response.json();
    } catch (_) {}
    if (Object.keys(levels).length === 0) await sleep(5000);
  }
  if (Object.keys(levels).length === 0) {
    serverProblem = 'no server levels after 150 s: the upload never got through';
    console.log(`  ${serverProblem}`);
  } else {
    const shown = Object.entries(levels).map(([type, e]) => `${type} ${(e.level / 100).toFixed(2)}`);
    console.log(`  server levels: ${shown.join(', ')} (${((Date.now() - started) / 1000).toFixed(0)} s)`);
  }
}

step('delete my data (cleans up the test account)');
await tapText('Delete my data', 30000, { exact: true, scroll: true });
await tapText('Delete', 30000, { exact: true });
// The app says either outcome; report the failure in its own words (e.g.
// the SQL function not installed in the project).
{
  const end = Date.now() + 30000;
  let outcome = null;
  while (!outcome && Date.now() < end) {
    if (await findText('Your data was deleted.')) outcome = 'deleted';
    else if (await findText('Nothing was deleted')) {
      outcome = await evaluate(`[...document.querySelectorAll('flt-semantics, flt-semantics *')]
        .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim())
        .find((t) => t.startsWith('Nothing was deleted')) || 'Nothing was deleted'`);
    } else await sleep(300);
  }
  if (outcome !== 'deleted') {
    await fail(`account deletion: ${outcome ?? 'no outcome shown'} — guest ${id} left behind`);
  }
}

// A confirmed account plays a rated duel (Phase 6c commit 6; review M12:
// the staging smoke test played no duel). The staging project confirms
// addresses by email, so the test cannot make one: it signs in to a
// confirmed account kept for it (SMOKE_DUEL_EMAIL, SMOKE_DUEL_PASSWORD),
// races a run or a practice opponent, and signs out — never deletes it.
// The guest the app makes after the sign-out has no game; the stale-guest
// cleanup removes it after 30 days.
const duelEmail = process.env.SMOKE_DUEL_EMAIL;
const duelPassword = process.env.SMOKE_DUEL_PASSWORD;
if (duelEmail && duelPassword) {
  step('sign in to the confirmed test account, play a rated Basics duel, sign out');
  await tapText('Profile', 60000, { exact: true });
  await tapText('I already have an account', 30000, { exact: true, scroll: true });
  // No failure screenshot while the account's address is on screen.
  codeOnScreen = true;
  await tapText('Email', 15000, { exact: true });
  await send('Input.insertText', { text: duelEmail });
  await tapText('Password', 10000, { exact: true });
  await send('Input.insertText', { text: duelPassword });
  // Enter submits (the screen's title says "Sign in" too).
  await pressKey('Enter');
  await waitForText('Sign out', 60000, { exact: true, scroll: true });
  codeOnScreen = false;
  await tapText('Online', 30000, { exact: true });
  await tapText('Basics', 60000, { exact: true });
  // The rules before the mode's first rated duel on this browser (plan v4.1).
  await waitForText('Basics duel', 30000, { exact: true });
  await tapText('Start', 10000, { exact: true });
  // A sleeping staging server takes up to a minute to wake.
  await waitForPattern('(^|[^0-9])1 / 8($|[^0-9])', 120000);
  for (let q = 0; q < 8; q++) {
    await pressKey('1');
    await pressKey('Enter');
    await sleep(1600);
  }
  await waitForText('Rematch', 60000, { exact: true });
  console.log(`  duel played to its result (${((Date.now() - started) / 1000).toFixed(0)} s)`);
  await tapText('Online', 10000, { exact: true });
  await tapText('Profile', 30000, { exact: true });
  await tapText('Sign out', 30000, { exact: true, scroll: true });
  await waitForText('Sign out?', 10000, { exact: true });
  await tapText('Sign out', 10000, { exact: true });
  await waitForText('Play Basics', 60000, { exact: true });
  console.log('  signed out');
} else {
  const why = 'duel skipped: SMOKE_DUEL_EMAIL / SMOKE_DUEL_PASSWORD (a confirmed account of the project) not set';
  console.log(`  ${why}`);
  if (process.env.GITHUB_ACTIONS) console.log(`::warning title=Smoke test::${why}`);
}

if (serverProblem) await fail(serverProblem);
if (soundProblem) await fail(soundProblem);
if (installProblem) await fail(installProblem);
console.log(`SMOKE PASSED in ${((Date.now() - started) / 1000).toFixed(0)} s`);
await shutdown(0);
