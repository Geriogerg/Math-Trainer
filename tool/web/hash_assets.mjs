// Content-hashed names for the files that change with a build (Phase 6a
// commit 5, review finding M9): `main.dart.js` becomes
// `main.<hash>.dart.js`, and CanvasKit moves to `canvaskit/<hash>/`. A
// hashed file never changes under its name, so it is served cached for a
// year (tool/cloudflare/functions/[[path]].js): a returning player's
// browser asks for nothing, and the Pages Function is not called.
//
//   node tool/web/hash_assets.mjs <site dir>
//
// Rewrites the two references in flutter_bootstrap.js: the build config's
// `"mainJsPath"` and the loader's `canvasKitBaseUrl`. Run after
// boot_config.mjs, before precompress.mjs (CI's web build). Fails loudly if
// a reference is not where it expects it: a build that would load the old
// names must never be deployed.
import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, renameSync, mkdirSync, statSync, writeFileSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

const site = process.argv[2];
if (!site) {
  console.error('usage: node hash_assets.mjs <site dir>');
  process.exit(2);
}

/// The first 10 hex characters of a SHA-256: plenty for a handful of files.
const short = (hash) => hash.digest('hex').slice(0, 10);

function* files(dir) {
  for (const name of readdirSync(dir).sort()) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) yield* files(path);
    else yield path;
  }
}

function fail(message) {
  console.error(`hash_assets: ${message}`);
  process.exit(1);
}

const bootstrapPath = join(site, 'flutter_bootstrap.js');
let bootstrap = readFileSync(bootstrapPath, 'utf8');

// main.dart.js
const mainPath = join(site, 'main.dart.js');
const mainHash = short(createHash('sha256').update(readFileSync(mainPath)));
const mainName = `main.${mainHash}.dart.js`;
const mainRef = '"mainJsPath":"main.dart.js"';
if (bootstrap.split(mainRef).length !== 2) fail(`expected one ${mainRef} in flutter_bootstrap.js`);
bootstrap = bootstrap.replace(mainRef, `"mainJsPath":"${mainName}"`);
renameSync(mainPath, join(site, mainName));
const mainMap = join(site, 'main.dart.js.map');
try {
  renameSync(mainMap, join(site, `${mainName}.map`));
} catch {
  // No source map in a release build: nothing to move.
}

// canvaskit/ → canvaskit/<hash>/, the hash over every file's path and bytes.
const canvaskit = join(site, 'canvaskit');
const kitHash = createHash('sha256');
const kitFiles = [...files(canvaskit)];
if (kitFiles.length === 0) fail('canvaskit/ is empty');
for (const path of kitFiles) {
  kitHash.update(relative(canvaskit, path).split(sep).join('/'));
  kitHash.update(readFileSync(path));
}
const kitDir = short(kitHash);
for (const path of kitFiles) {
  const target = join(canvaskit, kitDir, relative(canvaskit, path));
  mkdirSync(join(target, '..'), { recursive: true });
  renameSync(path, target);
}
// The loader's config, as web/flutter_bootstrap.js writes it.
const configRef = "config: { fontFallbackBaseUrl: 'fonts/' }";
if (bootstrap.split(configRef).length !== 2) fail(`expected one ${configRef} in flutter_bootstrap.js`);
bootstrap = bootstrap.replace(
  configRef,
  `config: { fontFallbackBaseUrl: 'fonts/', canvasKitBaseUrl: 'canvaskit/${kitDir}/' }`,
);

writeFileSync(bootstrapPath, bootstrap);
console.log(`hashed: ${mainName}, canvaskit/${kitDir}/ (${kitFiles.length} files)`);
