// First load (Phase 5.1 commit 1): the large build files, compressed once
// with brotli at its highest quality, next to the originals (`<file>.br`),
// and the `_routes.json` that sends only those paths through the Pages
// Function serving them (functions/[[path]].js), and `_precompressed.json`,
// the list of files that have a copy: the asset server answers 200 for a
// missing `.br` too (its fallback page), so the Function must know.
//
//   node tool/cloudflare/precompress.mjs <site dir>
//
// Cloudflare compresses on the fly at a lower quality: on slow 4G the
// difference is about 840 KB, four seconds (doc/decisions.md, "First
// load: pre-compressed files"). Run by CI's Cloudflare deploy only.
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { brotliCompressSync, constants } from 'node:zlib';

/// The paths the Function handles (Cloudflare `_routes.json` syntax), and
/// so the only ones pre-compressed. Everything else stays static.
export const routes = [
  '/main.dart.js',
  '/sqlite3.wasm',
  '/canvaskit/*',
  '/assets/assets/fonts/*',
  '/assets/fonts/*',
];

/// Smaller files gain too little to be worth a Function call.
const minBytes = 16 * 1024;
const compressible = /\.(js|mjs|wasm|ttf|otf)$/;

const site = process.argv[2];
if (!site) {
  console.error('usage: node precompress.mjs <site dir>');
  process.exit(2);
}

const matches = (path) =>
  routes.some((r) => (r.endsWith('/*') ? path.startsWith(r.slice(0, -1)) : path === r));

function* files(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) yield* files(path);
    else yield path;
  }
}

let before = 0;
let after = 0;
const done = [];
for (const path of files(site)) {
  const url = '/' + relative(site, path).split(sep).join('/');
  if (!matches(url) || !compressible.test(url)) continue;
  const body = readFileSync(path);
  if (body.length < minBytes) continue;
  const br = brotliCompressSync(body, {
    params: {
      [constants.BROTLI_PARAM_QUALITY]: 11,
      [constants.BROTLI_PARAM_SIZE_HINT]: body.length,
    },
  });
  writeFileSync(path + '.br', br);
  done.push(url);
  before += body.length;
  after += br.length;
  console.log(`${url}: ${(body.length / 1024).toFixed(0)} → ${(br.length / 1024).toFixed(0)} KB`);
}
if (after === 0) {
  console.error('nothing pre-compressed: is this a Flutter web build?');
  process.exit(1);
}
writeFileSync(
  join(site, '_routes.json'),
  JSON.stringify({ version: 1, include: routes, exclude: [] }, null, 2) + '\n',
);
writeFileSync(join(site, '_precompressed.json'), JSON.stringify(done.sort(), null, 2) + '\n');
console.log(`total ${(before / 1024).toFixed(0)} → ${(after / 1024).toFixed(0)} KB brotli 11`);
