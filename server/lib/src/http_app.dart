import 'dart:convert';

import 'package:shelf/shelf.dart';

import 'config.dart';

/// A route: method + exact path → handler.
typedef Route = ({String method, String path, Handler handler});

/// The whole HTTP surface: CORS for the allowed web origins, JSON errors,
/// then [routes] plus `GET /health`. A handful of exact paths: no router
/// dependency.
Handler buildHandler(ServerConfig config, {List<Route> routes = const []}) {
  final all = <Route>[
    (method: 'GET', path: '/health', handler: _health),
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

Response _health(Request request) =>
    jsonResponse(200, {'status': 'ok', 'service': 'math_trainer_server'});

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
Middleware _cors(Set<String> allowedOrigins) =>
    (inner) => (request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null && allowedOrigins.contains(origin);
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
