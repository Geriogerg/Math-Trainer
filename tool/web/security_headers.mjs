// The site's security headers (Phase 6a commit 6, review finding m6): a
// Cloudflare Pages `_headers` file written into the build, with a Content
// Security Policy that names this build's own backend (the Supabase project
// and the Dart server, from dart_defines.json) and nothing else.
//
//   node tool/web/security_headers.mjs <site dir> <dart_defines.json>
//
// - frame-ancestors 'none' (and X-Frame-Options): the app, "Delete my
//   account" included, can never be framed by another site.
// - script-src keeps 'unsafe-inline': index.html signs in and draws the
//   loading screen with inline scripts (window.mtBootAuth); a hash list
//   would break with every edit of them. 'wasm-unsafe-eval' for CanvasKit
//   and sqlite3.wasm. No 'unsafe-eval'.
// - connect-src: this site, the Supabase project (HTTPS and its realtime
//   socket) and the server — the only places the app talks to.
// Applies to the static files (index.html above all); the Pages Function's
// own responses carry nosniff themselves.
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const [site, definesPath] = process.argv.slice(2);
if (!site || !definesPath) {
  console.error('usage: node security_headers.mjs <site dir> <dart_defines.json>');
  process.exit(2);
}
const defines = JSON.parse(readFileSync(definesPath, 'utf8'));

/// The origin of [value] if it is an https URL, else null.
function origin(value) {
  try {
    const url = new URL(String(value ?? '').trim());
    return url.protocol === 'https:' ? url.origin : null;
  } catch {
    return null;
  }
}

const supabase = origin(defines.SUPABASE_URL);
const server = origin(defines.SERVER_URL);
const connect = ["'self'"];
if (supabase) connect.push(supabase, supabase.replace(/^https:/, 'wss:'));
if (server) connect.push(server);

const csp = [
  "default-src 'self'",
  "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self' data:",
  `connect-src ${connect.join(' ')}`,
  "worker-src 'self' blob:",
  "manifest-src 'self'",
  "object-src 'none'",
  "base-uri 'self'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join('; ');

const headers = `/*
  Content-Security-Policy: ${csp}
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()
`;
writeFileSync(join(site, '_headers'), headers);
console.log(`_headers written; connect-src ${connect.join(' ')}`);
