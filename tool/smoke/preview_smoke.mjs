// Preview smoke test (Phase 1 commit 8): a fresh browser plays the deployed
// app like a new visitor, then deletes the account it created.
//
//   node tool/smoke/preview_smoke.mjs <app url> [chrome executable]
//
// SMOKE_NETWORK=slow4g (or fast4g) emulates that network with an empty
// cache — the plan's exit test: the first question within 30 s on slow 4G
// from a fresh browser. The times are printed either way.
//
// Steps, each failing loudly with a screenshot (smoke-failure.png):
//   1. fresh profile → an anonymous player is created (no form);
//   2. the placement offer is skipped; a 2-type game (8 questions) is played
//      to its result screen — every answer typed at once ("1", Enter), so the
//      per-question timeout (always on in a release build) never fires;
//   3. reload → Profile shows the game's answers (history survived);
//   4. "Delete my data" → the account is deleted (cleans up after itself:
//      anonymous sign-ins are rate-limited per IP, and the project must not
//      fill with test players).
//
// The app draws on a canvas: the script turns Flutter's accessibility tree
// on and finds widgets by their text in that DOM. Only Node (>= 22, global
// WebSocket) and Chrome — nothing to install.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [appUrl, chromePath = 'google-chrome'] = process.argv.slice(2);
if (!appUrl) {
  console.error('usage: node preview_smoke.mjs <app url> [chrome]');
  process.exit(2);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
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
const wsBrowserUrl = await new Promise((resolve, reject) => {
  let buffer = '';
  chrome.stderr.on('data', (chunk) => {
    buffer += chunk;
    const m = buffer.match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) resolve(m[1]);
  });
  chrome.on('exit', (code) => reject(new Error(`chrome exited (${code})`)));
  setTimeout(() => reject(new Error('chrome did not start')), 30000);
});
const port = new URL(wsBrowserUrl).port;
const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
const page = targets.find((t) => t.type === 'page' && /^(https?:|about:)/.test(t.url));
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r, { once: true }));
let nextId = 1;
const pending = new Map();
const consoleErrors = [];
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  } else if (msg.method === 'Runtime.exceptionThrown') {
    consoleErrors.push(msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text);
  }
});
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
await send('Emulation.setDeviceMetricsOverride', { width: 412, height: 800, deviceScaleFactor: 1, mobile: false });
// Same profiles as the first-load measurements (doc/architecture.md).
const networks = {
  fast4g: { latency: 60, downloadThroughput: (9000 * 1024) / 8, uploadThroughput: (1500 * 1024) / 8 },
  slow4g: { latency: 150, downloadThroughput: (1600 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 },
};
const network = networks[process.env.SMOKE_NETWORK ?? ''];
if (network) {
  await send('Network.enable');
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  await send('Network.emulateNetworkConditions', { offline: false, ...network });
  console.log(`network: ${process.env.SMOKE_NETWORK}, cache disabled`);
}

// --- helpers ---------------------------------------------------------------
async function fail(message) {
  try {
    const { data } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync('smoke-failure.png', Buffer.from(data, 'base64'));
  } catch (_) {}
  console.error(`SMOKE FAILED: ${message}`);
  if (consoleErrors.length) console.error('page exceptions:\n  ' + consoleErrors.join('\n  '));
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
      if (r.bottom <= 0 || r.top >= innerHeight) continue;
      if (!best || r.width * r.height < best.area) {
        best = { x: r.left + r.width / 2, y: r.top + r.height / 2, area: r.width * r.height };
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

// --- the visit -------------------------------------------------------------
const step = (s) => console.log(`- ${s}`);
const started = Date.now();

step(`open ${appUrl} in a fresh browser`);
await send('Page.navigate', { url: appUrl });
await enableSemantics();

step('a guest is created, no form: the placement offer appears');
await waitForText('Find my level', 60000);
const id = await guestId();
if (!id) await fail('no anonymous session stored');
console.log(`  guest ${id} (${((Date.now() - started) / 1000).toFixed(1)} s from navigation)`);

step('skip the placement, start the default 2-type game');
await tapText('Skip', 30000, { exact: true });
await tapText('Start', 30000, { exact: true });
await waitForText('1 / 8');
// Two taps (Skip, Start) included: what a new visitor going straight to a
// game experiences, at script speed.
console.log(`  first question ${((Date.now() - started) / 1000).toFixed(1)} s from navigation`);

step('answer the 8 questions');
for (let q = 0; q < 8; q++) {
  await pressKey('1');
  await pressKey('Enter');
  await sleep(1600); // a wrong answer shows its correction for 1 s
}
await waitForText('Session complete', 20000);

step('reload: same guest, history kept');
await send('Page.reload', {});
await enableSemantics();
await tapText('Profile', 60000, { exact: true });
if ((await guestId()) !== id) await fail('a reload changed the player');
await waitForText(' ms'); // "Level 1 · 1234 ms" — an operation with answers

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

console.log(`SMOKE PASSED in ${((Date.now() - started) / 1000).toFixed(0)} s`);
await shutdown(0);
