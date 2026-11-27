// Writes the boot sign-in's settings into a Flutter web build's index.html
// (Phase 5.1 commit 1): the Supabase address and publishable key — both
// public, the app's main.dart.js carries them too — and whether the beta
// gate is on, read from the same dart-defines file the build used. With
// SITE_URL there, the link preview's image gets its full address too
// (Phase 6c commit 1).
//
//   node tool/web/boot_config.mjs <build/web> <dart_defines.json>
//
// Without it the page still works: the app signs in after it starts, as it
// did before (web/index.html, window.mtBootAuth).
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [site, definesPath] = process.argv.slice(2);
if (!site || !definesPath) {
  console.error('usage: node boot_config.mjs <build/web> <dart_defines.json>');
  process.exit(2);
}
const defines = JSON.parse(readFileSync(definesPath, 'utf8'));
const supabaseUrl = String(defines.SUPABASE_URL ?? '').trim().replace(/\/+$/, '');
const publishableKey = String(defines.SUPABASE_PUBLISHABLE_KEY ?? '').trim();
if (!/^https:\/\/[^/]+$/.test(supabaseUrl) || !publishableKey) {
  console.error('SUPABASE_URL (https) and SUPABASE_PUBLISHABLE_KEY are needed');
  process.exit(1);
}
// The secret key must never reach a page (rule 17).
const legacyRole = (() => {
  try {
    return JSON.parse(Buffer.from(publishableKey.split('.')[1], 'base64url')).role;
  } catch {
    return null;
  }
})();
if (publishableKey.startsWith('sb_secret_') || (legacyRole && legacyRole !== 'anon')) {
  console.error('SUPABASE_PUBLISHABLE_KEY holds a secret key: refusing to write it');
  process.exit(1);
}
const config = {
  supabaseUrl,
  publishableKey,
  betaGate: String(defines.BETA_GATE ?? '') === 'true',
};
const marker = 'window.mtBootConfig = null; /*__MT_BOOT_CONFIG__*/';
const page = join(site, 'index.html');
const html = readFileSync(page, 'utf8');
if (!html.includes(marker)) {
  console.error(`${page}: the boot config marker is missing`);
  process.exit(1);
}
// `<` escaped: nothing in the values can close the script element.
const json = JSON.stringify(config).replace(/</g, '\u003c');
let written = html.replace(marker, `window.mtBootConfig = ${json};`);

// The link preview (Phase 6c commit 1): most sites that unfurl a link need
// the image's full address, which only the build knows — SITE_URL, the
// address the site is served from (the domain after the switch-on). Without
// it the relative path stays (enough for some, not all).
const siteUrl = String(defines.SITE_URL ?? '').trim().replace(/\/+$/, '');
if (siteUrl) {
  if (!/^https:\/\/[^/"<>\s]+$/.test(siteUrl)) {
    console.error(`SITE_URL must be an https origin, got ${siteUrl}`);
    process.exit(1);
  }
  const image = '<meta property="og:image" content="preview.png">';
  if (!written.includes(image)) {
    console.error(`${page}: no relative og:image to complete`);
    process.exit(1);
  }
  written = written
    .replace(image, `<meta property="og:image" content="${siteUrl}/preview.png">`)
    .replace('  <!-- /brand -->', `  <meta property="og:url" content="${siteUrl}/">\n  <!-- /brand -->`);
}
writeFileSync(page, written);
console.log(`boot config written (beta gate ${config.betaGate ? 'on' : 'off'}; link preview ${siteUrl || 'relative'})`);
