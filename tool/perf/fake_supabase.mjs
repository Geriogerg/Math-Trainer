// A stand-in for Supabase on localhost (Phase 6c commit 0): enough of the
// auth and RPC API for a local release build to sign in as a guest and
// reach Home, so a measurement never creates a player on a real project
// (CLAUDE.md: never point a test that creates accounts at production).
//
//   import { startFakeSupabase } from './fake_supabase.mjs';
//   const server = await startFakeSupabase(54399);
//
// Build the app against it:
//   --dart-define=SUPABASE_URL=http://127.0.0.1:54399
//   --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_local
// Every answer is a guest's: no level on the server, no duel, no profile.
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

const base64url = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');

/// An unsigned token the client can read (it only decodes the payload).
function token(userId, expiresAt) {
  return [
    base64url({ alg: 'HS256', typ: 'JWT' }),
    base64url({ sub: userId, role: 'authenticated', aud: 'authenticated', exp: expiresAt, is_anonymous: true }),
    'local',
  ].join('.');
}

function user(id) {
  const now = new Date().toISOString();
  return {
    id,
    aud: 'authenticated',
    role: 'authenticated',
    email: '',
    phone: '',
    is_anonymous: true,
    app_metadata: {},
    user_metadata: {},
    identities: [],
    created_at: now,
    updated_at: now,
  };
}

function session(id) {
  const expiresAt = Math.floor(Date.now() / 1000) + 3600;
  return {
    access_token: token(id, expiresAt),
    token_type: 'bearer',
    expires_in: 3600,
    expires_at: expiresAt,
    refresh_token: `refresh-${id}`,
    user: user(id),
  };
}

/// What each function answers: a guest with nothing on the server.
const rpcAnswers = {
  duel_overview: { linked: false },
  my_account_under_review: false,
  my_server_levels: [],
};

export function startFakeSupabase(port) {
  const server = createServer((request, response) => {
    const url = new URL(request.url, `http://127.0.0.1:${port}`);
    const send = (status, body) => {
      response.writeHead(status, {
        'access-control-allow-origin': request.headers.origin ?? '*',
        'access-control-allow-headers': request.headers['access-control-request-headers'] ?? '*',
        'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
        'content-type': 'application/json',
      });
      response.end(body === undefined ? '' : JSON.stringify(body));
    };
    let body = '';
    request.on('data', (chunk) => (body += chunk));
    request.on('end', () => {
      if (request.method === 'OPTIONS') return send(204);
      const path = url.pathname;
      if (path === '/auth/v1/signup') return send(200, session(randomUUID()));
      if (path === '/auth/v1/token') {
        // A refresh keeps the player: the id is in the refresh token.
        let id = randomUUID();
        try {
          id = JSON.parse(body).refresh_token.replace(/^refresh-/, '');
        } catch (_) {}
        return send(200, session(id));
      }
      if (path === '/auth/v1/user') {
        const auth = request.headers.authorization ?? '';
        try {
          const payload = JSON.parse(Buffer.from(auth.split('.')[1], 'base64url'));
          return send(200, user(payload.sub));
        } catch (_) {
          return send(401, { message: 'no token' });
        }
      }
      if (path === '/auth/v1/logout') return send(204);
      const rpc = path.match(/^\/rest\/v1\/rpc\/([a-z_]+)$/);
      if (rpc) return send(200, rpc[1] in rpcAnswers ? rpcAnswers[rpc[1]] : []);
      if (path.startsWith('/rest/v1/')) return send(200, []);
      return send(404, { message: `not faked: ${path}` });
    });
  });
  return new Promise((resolve) => server.listen(port, '127.0.0.1', () => resolve(server)));
}
