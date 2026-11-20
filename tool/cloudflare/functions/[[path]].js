// Cloudflare Pages Function (Phase 5.1 commit 1): serves the build's large
// files from their pre-compressed copies (`<file>.br`, brotli quality 11,
// made by tool/cloudflare/precompress.mjs) instead of Cloudflare's own
// on-the-fly compression — about a quarter smaller. Only the paths of
// `_routes.json` reach it; anything it cannot serve goes on unchanged.

const types = {
  js: 'text/javascript; charset=utf-8',
  mjs: 'text/javascript; charset=utf-8',
  // WebAssembly.instantiateStreaming refuses any other type.
  wasm: 'application/wasm',
  ttf: 'font/ttf',
  otf: 'font/otf',
};

/// The paths that have a `.br` copy (`_precompressed.json`, written with
/// them), read once per isolate. Never guessed from the asset server: it
/// answers 200 for a missing file too.
let compressed = null;
function compressedPaths(env, url) {
  compressed ??= env.ASSETS.fetch(new URL('/_precompressed.json', url))
    .then((r) => (r.ok ? r.json() : []))
    .then((paths) => new Set(Array.isArray(paths) ? paths : []))
    .catch(() => {
      compressed = null;
      return new Set();
    });
  return compressed;
}

export async function onRequest({ request, env, next }) {
  const url = new URL(request.url);
  const type = types[url.pathname.split('.').pop()];
  const acceptsBrotli = /\bbr\b/.test(request.headers.get('accept-encoding') ?? '');
  if (!type || !acceptsBrotli || (request.method !== 'GET' && request.method !== 'HEAD')) {
    return next();
  }
  if (!(await compressedPaths(env, url)).has(url.pathname)) return next();

  // No Accept-Encoding: the asset server returns the .br file's own bytes.
  const headers = new Headers();
  const ifNoneMatch = request.headers.get('if-none-match');
  if (ifNoneMatch) headers.set('if-none-match', ifNoneMatch);
  const asset = await env.ASSETS.fetch(
    new Request(new URL(url.pathname + '.br', url), { method: request.method, headers }),
  );
  if (asset.status !== 200 && asset.status !== 304) return next();

  const out = new Headers({
    'content-type': type,
    'cache-control': 'public, max-age=0, must-revalidate',
    vary: 'accept-encoding',
  });
  const etag = asset.headers.get('etag');
  if (etag) out.set('etag', etag);
  if (asset.status === 304) return new Response(null, { status: 304, headers: out });
  out.set('content-encoding', 'br');
  // `manual`: the body is already brotli — sent as is, never re-encoded.
  return new Response(request.method === 'HEAD' ? null : asset.body, {
    status: 200,
    headers: out,
    encodeBody: 'manual',
  });
}
