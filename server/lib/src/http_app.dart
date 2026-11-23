import 'dart:convert';

import 'package:math_core/leveling/rules_version.dart';
import 'package:shelf/shelf.dart';

import 'config.dart';

/// A route: method + exact path → handler.
typedef Route = ({String method, String path, Handler handler});

/// The whole HTTP surface: CORS for the allowed web origins, JSON errors,
/// then [routes] plus `GET /health`. A handful of exact paths: no router
/// dependency.
Handler buildHandler(ServerConfig config, {List<Route> routes = const []}) {
  final all = <Route>[
    (
      method: 'GET',
      path: '/health',
      handler: (_) => jsonResponse(200, {
        'status': 'ok',
        'service': 'math_trainer_server',
        // Which commit runs (Phase 5.1): the repository is private, so a
        // deploy is checked from outside by asking the server itself.
        'version': config.version,
        'betaGate': config.requireBetaCode,
        // The rules versions this server replays (Levels phase): the app
        // sends a session only to a server that knows its rules.
        'rules': [for (final v in RulesVersion.replayed) v.number],
      }),
    ),
    ...routes,
  ];
  return const Pipeline()
      .addMiddleware(_cors(config.allowedOrigins))
      .addMiddleware(_jsonErrors())
      .addHandler((request) {
        final path = '/${request.url.path}';
        final matching = all.where((r) => r.path == path).toList();
        if (matching.isEmpty) return jsonResponse(404, {'error': 'not_found'});
        for (final route in matching) {
          if (route.method == request.method) return route.handler(request);
        }
        return jsonResponse(405, {'error': 'method_not_allowed'});
      });
}

Response jsonResponse(int status, Object body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// The web app (another origin: GitHub Pages) calls with an
/// `Authorization` header, so browsers send a preflight `OPTIONS` first.
/// Only listed origins get the CORS headers; others are refused by the
/// browser, never by a server-side check of `Origin` (not a security
/// boundary: the bearer token is).
/// Whether [origin] is one of [allowed]: an exact address, or a pattern
/// with one `*` standing for letters, digits and dashes inside a single
/// label (Phase 5.2: `https://math-trainer-staging*.pages.dev` matches the
/// staging site whatever suffix Cloudflare gave it, never another domain).
bool originAllowed(String origin, Set<String> allowed) {
  for (final pattern in allowed) {
    if (pattern == origin) return true;
    final star = pattern.indexOf('*');
    if (star < 0 || pattern.indexOf('*', star + 1) >= 0) continue;
    final regex = RegExp(
      '^${RegExp.escape(pattern.substring(0, star))}'
      '[a-z0-9-]*'
      '${RegExp.escape(pattern.substring(star + 1))}\$',
    );
    if (regex.hasMatch(origin)) return true;
  }
  return false;
}

Middleware _cors(Set<String> allowedOrigins) =>
    (inner) => (request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null && originAllowed(origin, allowedOrigins);
      final headers = {
        if (allowed) ...{
          'access-control-allow-origin': origin,
          'access-control-allow-methods': 'GET, POST, OPTIONS',
          'access-control-allow-headers': 'authorization, content-type',
          'access-control-max-age': '600',
        },
        'vary': 'Origin',
      };
      if (request.method == 'OPTIONS') return Response(204, headers: headers);
      final response = await inner(request);
      return response.change(headers: headers);
    };

/// An unexpected exception becomes a JSON 500 without its details: they
/// may hold request data. Logged by the host from stderr.
Middleware _jsonErrors() =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on HijackException {
        rethrow;
      } catch (error, stack) {
        // ignore: avoid_print
        print('500 on ${request.method} /${request.url.path}: $error\n$stack');
        return jsonResponse(500, {'error': 'internal'});
      }
    };
