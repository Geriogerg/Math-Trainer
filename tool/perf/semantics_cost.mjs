// What the accessibility tree costs a low-end phone (Phase 6c commit 0;
// plan v4.1: semantics stay on for everyone, measured here — if the cost is
// real, they come on only when a screen reader asks).
//
//   node tool/perf/semantics_cost.mjs <build on> <build off> [browser] [runs]
//
// <build on>, <build off>: two release builds of the app against the local
// fake Supabase (fake_supabase.mjs, started here on port 54399), the second
// with --dart-define=SEMANTICS_ALWAYS=false:
//
//   flutter build web --release --no-web-resources-cdn \
//     --dart-define=SUPABASE_URL=http://127.0.0.1:54399 \
//     --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_local [...]
//
// The profile: Chrome DevTools' "low-end mobile" CPU (6× slower), a
// 360 × 780 screen at 2× density, the cache off (a first visit), the files
// from localhost (the network is not what differs). Per run and build:
// - first frame: navigation to Flutter's first frame, and the main
//   thread's busy time until then;
// - a game: 10 answers typed 1.6 s apart (Home → Play Basics → Start, the
//   taps located in the build with semantics and reused in the other) —
//   frame intervals (requestAnimationFrame), long tasks, busy time per
//   second, DOM size.
// Builds alternate run by run, so a slower minute hits both.
import { spawn } from 'node:child_process';
import { createReadStream, existsSync, mkdtempSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { extname, join, resolve } from 'node:path';

import { startFakeSupabase } from './fake_supabase.mjs';

const [onDir, offDir, browserPath = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', runsArg = '5'] =
  process.argv.slice(2);
if (!onDir || !offDir) {
  console.error('usage: node semantics_cost.mjs <build on> <build off> [browser] [runs]');
  process.exit(2);
}
const runs = Number(runsArg);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- local files ---------------------------------------------------------------
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png', '.ico': 'image/x-icon',
  '.css': 'text/css', '.svg': 'image/svg+xml', '.bin': 'application/octet-stream', '.frag': 'application/octet-stream',
};
function serve(dir, port) {
  const root = resolve(dir);
  const server = createServer((request, response) => {
    let path = decodeURIComponent(new URL(request.url, 'http://x').pathname);
    let file = join(root, path);
    if (!file.startsWith(root) || !existsSync(file) || statSync(file).isDirectory()) file = join(root, 'index.html');
    response.writeHead(200, { 'content-type': types[extname(file)] ?? 'application/octet-stream', 'cache-control': 'no-store' });
    createReadStream(file).pipe(response);
  });
  return new Promise((r) => server.listen(port, '127.0.0.1', () => r(server)));
}

// --- one visit -----------------------------------------------------------------
async function visit(url, taps) {
  const profile = mkdtempSync(join(tmpdir(), 'mt-perf-'));
  const browser = spawn(browserPath, [
    '--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
    '--no-first-run', '--disable-extensions', '--window-size=360,780', 'about:blank',
  ], { stdio: ['ignore', 'ignore', 'pipe'] });
  // Chrome prints its DevTools address; Edge on Windows only writes it to
  // the profile's DevToolsActivePort: read either.
  const port = await new Promise((ok, ko) => {
    let buffer = '';
    browser.stderr.on('data', (c) => {
      buffer += c;
      const m = buffer.match(/DevTools listening on ws:\/\/[^:]+:(\d+)/);
      if (m) ok(m[1]);
    });
    const poll = setInterval(() => {
      const file = join(profile, 'DevToolsActivePort');
      if (existsSync(file)) {
        let first = '';
        try {
          first = readFileSync(file, 'utf8').split(/\r?\n/)[0].trim();
        } catch (_) {
          // Still being written (EBUSY on Windows): the next poll.
        }
        if (first) {
          clearInterval(poll);
          ok(first);
        }
      }
    }, 200);
    setTimeout(() => {
      clearInterval(poll);
      ko(new Error('browser did not start'));
    }, 30000);
  });
  const page = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find((t) => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r, { once: true }));
  let id = 0;
  const waiting = new Map();
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && waiting.has(m.id)) {
      waiting.get(m.id)(m);
      waiting.delete(m.id);
    }
  });
  const send = (method, params = {}) => new Promise((ok, ko) => {
    const n = ++id;
    waiting.set(n, (m) => (m.error ? ko(new Error(`${method}: ${JSON.stringify(m.error)}`)) : ok(m.result)));
    ws.send(JSON.stringify({ id: n, method, params }));
  });
  const evaluate = async (expression) =>
    (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true })).result?.value;
  const busy = async () => {
    const { metrics } = await send('Performance.getMetrics');
    const get = (name) => metrics.find((m) => m.name === name)?.value ?? 0;
    return { task: get('TaskDuration') * 1000, heap: get('JSHeapUsedSize') };
  };
  const click = async ({ x, y }) => {
    for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
      await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
      await sleep(30);
    }
  };
  const key = async (k) => {
    const digit = /^[0-9]$/.test(k);
    const vk = digit ? k.charCodeAt(0) : 13;
    const base = { key: k, code: digit ? `Digit${k}` : k, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk };
    await send('Input.dispatchKeyEvent', { type: digit ? 'keyDown' : 'rawKeyDown', ...base, ...(digit ? { text: k } : {}) });
    if (!digit) await send('Input.dispatchKeyEvent', { type: 'char', ...base, text: '\r' });
    await send('Input.dispatchKeyEvent', { type: 'keyUp', ...base });
  };
  // The centre of the smallest semantics node labelled [text], or null.
  const find = (text) => evaluate(`(() => {
    let best = null;
    for (const el of document.querySelectorAll('flt-semantics, flt-semantics *')) {
      const t = [el.getAttribute('aria-label') || '', el.textContent || ''].map((s) => s.trim());
      if (!t.includes(${JSON.stringify(text)})) continue;
      const r = el.getBoundingClientRect();
      if (!r.width || !r.height) continue;
      if (!best || r.width * r.height < best.a) best = { x: r.left + r.width / 2, y: r.top + r.height / 2, a: r.width * r.height };
    }
    return best;
  })()`);
  const waitFor = async (text, ms) => {
    const end = Date.now() + ms;
    while (Date.now() < end) {
      const hit = await find(text);
      if (hit) return hit;
      await sleep(200);
    }
    throw new Error(`"${text}" never appeared`);
  };

  try {
    await send('Page.enable');
    await send('Runtime.enable');
    await send('Performance.enable');
    await send('Network.enable');
    await send('Network.setCacheDisabled', { cacheDisabled: true });
    await send('Emulation.setCPUThrottlingRate', { rate: 6 });
    await send('Emulation.setDeviceMetricsOverride', { width: 360, height: 780, deviceScaleFactor: 2, mobile: true });
    await send('Page.addScriptToEvaluateOnNewDocument', {
      source: `(() => {
        const p = window.__perf = { firstFrame: null, frames: [], longTasks: [], recording: false, tones: 0 };
        addEventListener('flutter-first-frame', () => { p.firstFrame = performance.now(); }, { once: true });
        let last;
        const tick = (t) => { if (p.recording && last !== undefined) p.frames.push(t - last); last = t; requestAnimationFrame(tick); };
        requestAnimationFrame(tick);
        try {
          new PerformanceObserver((l) => { if (p.recording) for (const e of l.getEntries()) p.longTasks.push(e.duration); })
            .observe({ type: 'longtask', buffered: false });
        } catch (_) {}
        const AC = window.AudioContext;
        if (AC) {
          const create = AC.prototype.createOscillator;
          AC.prototype.createOscillator = function () { p.tones++; return create.apply(this, arguments); };
        }
      })();`,
    });
    await send('Page.navigate', { url });
    const end = Date.now() + 180000;
    while (!(await evaluate('window.__perf && window.__perf.firstFrame'))) {
      if (Date.now() > end) throw new Error('no first frame');
      await sleep(250);
    }
    const firstFrame = await evaluate('window.__perf.firstFrame');
    const atFirstFrame = await busy();

    // Home, then the setup, then the game.
    let play = taps?.play;
    let start = taps?.start;
    let home = null;
    if (!taps) {
      play = await waitFor('Play Basics', 120000);
      home = await evaluate('performance.now()');
      await click(play);
      start = await waitFor('Start', 60000);
      await click(start);
    } else {
      await sleep(taps.homeWaitMs);
      await click(play);
      await sleep(taps.setupWaitMs);
      await click(start);
    }
    await sleep(3000);

    await evaluate('window.__perf.recording = true');
    const before = await busy();
    const began = Date.now();
    for (let q = 0; q < 10; q++) {
      await key('1');
      await key('Enter');
      await sleep(1600);
    }
    const after = await busy();
    const seconds = (Date.now() - began) / 1000;
    await evaluate('window.__perf.recording = false');
    const game = await evaluate(`(() => {
      const p = window.__perf;
      return { frames: p.frames, longTasks: p.longTasks, tones: p.tones, dom: document.getElementsByTagName('*').length };
    })()`);
    if (game.tones === 0) throw new Error('no answer was heard: the game never ran');
    return {
      firstFrame, busyToFirstFrame: atFirstFrame.task, home,
      play, start, ...game, busyPerSecond: (after.task - before.task) / seconds, heap: after.heap,
    };
  } catch (error) {
    // What the page showed: perf-failure.png, beside where it ran.
    try {
      const { data } = await send('Page.captureScreenshot', { format: 'png' });
      writeFileSync('perf-failure.png', Buffer.from(data, 'base64'));
    } catch (_) {}
    throw error;
  } finally {
    try { ws.close(); } catch (_) {}
    browser.kill();
    await sleep(800);
    try { rmSync(profile, { recursive: true, force: true }); } catch (_) {}
  }
}

// --- statistics ------------------------------------------------------------------
const median = (xs) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length ? (s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2) : NaN;
};
const percentile = (xs, p) => {
  const s = [...xs].sort((a, b) => a - b);
  return s.length ? s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))] : NaN;
};
function summary(rows) {
  const frames = rows.flatMap((r) => r.frames);
  return {
    'first frame, s (median)': (median(rows.map((r) => r.firstFrame)) / 1000).toFixed(2),
    'first frame, s (range)': `${(Math.min(...rows.map((r) => r.firstFrame)) / 1000).toFixed(2)}–${(Math.max(...rows.map((r) => r.firstFrame)) / 1000).toFixed(2)}`,
    'busy until first frame, s': (median(rows.map((r) => r.busyToFirstFrame)) / 1000).toFixed(2),
    'game: frame interval p50, ms': percentile(frames, 50).toFixed(1),
    'game: frame interval p95, ms': percentile(frames, 95).toFixed(1),
    'game: frame interval p99, ms': percentile(frames, 99).toFixed(1),
    'game: frames over 50 ms, %': ((100 * frames.filter((f) => f > 50).length) / frames.length).toFixed(1),
    'game: long tasks per answer': (median(rows.map((r) => r.longTasks.length)) / 10).toFixed(2),
    'game: busy ms per second': median(rows.map((r) => r.busyPerSecond)).toFixed(0),
    'game: DOM elements': median(rows.map((r) => r.dom)).toFixed(0),
    'JS heap, MB': (median(rows.map((r) => r.heap)) / 1e6).toFixed(1),
  };
}

// --- main ------------------------------------------------------------------------
const supabase = await startFakeSupabase(54399);
const servers = [await serve(onDir, 8181), await serve(offDir, 8182)];
const results = { on: [], off: [] };
let taps = null;
try {
  for (let i = 0; i < runs; i++) {
    const on = await visit('http://127.0.0.1:8181/', null);
    results.on.push(on);
    if (!taps) {
      // The other build waits as long as the slowest Home seen, plus a margin.
      taps = { play: on.play, start: on.start, homeWaitMs: 0, setupWaitMs: 4000 };
    }
    taps.homeWaitMs = Math.max(taps.homeWaitMs, on.home - on.firstFrame + 4000);
    console.log(`run ${i + 1} on:  first frame ${(on.firstFrame / 1000).toFixed(2)} s, Home ${(on.home / 1000).toFixed(2)} s, ${on.dom} elements`);
    const off = await visit('http://127.0.0.1:8182/', taps);
    results.off.push(off);
    console.log(`run ${i + 1} off: first frame ${(off.firstFrame / 1000).toFixed(2)} s, ${off.dom} elements, ${off.tones} tones`);
  }
  const on = summary(results.on);
  const off = summary(results.off);
  console.log(`\n| ${runs} runs each | semantics on | off |\n|---|---|---|`);
  for (const k of Object.keys(on)) console.log(`| ${k} | ${on[k]} | ${off[k]} |`);
} finally {
  supabase.close();
  for (const s of servers) s.close();
}
