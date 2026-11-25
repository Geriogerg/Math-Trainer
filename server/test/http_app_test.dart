import 'dart:convert';

import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  final config = ServerConfig(
    supabaseUrl: Uri.parse('https://example.supabase.co'),
    supabaseSecretKey: 'sb_secret_test',
    allowedOrigins: {'https://geriogerg.github.io'},
  );
  final handler = buildHandler(
    config,
    routes: [
      (
        method: 'POST',
        path: '/v1/echo',
        handler: (request) async =>
            jsonResponse(200, {'echo': await request.readAsString()}),
      ),
      (
        method: 'GET',
        path: '/v1/boom',
        handler: (_) => throw StateError('secret detail'),
      ),
    ],
  );

  Future<Response> send(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
  }) async => handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: headers,
      body: body,
    ),
  );

  test('GET /health answers ok in JSON', () async {
    final response = await send('GET', '/health');
    expect(response.statusCode, 200);
    expect(jsonDecode(await response.readAsString()), {
      'status': 'ok',
      'service': 'math_trainer_server',
      'version': 'dev',
      'betaGate': true,
      // The rules it replays: the app holds sessions of others back.
      'rules': [2, 3, 4, 5, 6, 7, 8],
      // The kinds it accepts: the app holds the others back.
      'kinds': ['game', 'training', 'weakSpots', 'drill'],
      // Phase 7: the duel modes it plays and the duel rules it replays.
      'duelModes': ['basics', 'advanced', 'count'],
      'duelRules': [1],
    });
  });

  test('unknown path 404, wrong method 405', () async {
    expect((await send('GET', '/nope')).statusCode, 404);
    expect((await send('POST', '/health')).statusCode, 405);
  });

  test('a route receives its request', () async {
    final response = await send('POST', '/v1/echo', body: 'hi');
    expect(jsonDecode(await response.readAsString()), {'echo': 'hi'});
  });

  test('an exception becomes a JSON 500 without its details', () async {
    final response = await send('GET', '/v1/boom');
    expect(response.statusCode, 500);
    final body = await response.readAsString();
    expect(jsonDecode(body), {'error': 'internal'});
    expect(body, isNot(contains('secret detail')));
  });

  group('CORS', () {
    test('an allowed origin gets the headers, preflight included', () async {
      const origin = {'origin': 'https://geriogerg.github.io'};
      final preflight = await send('OPTIONS', '/v1/echo', headers: origin);
      expect(preflight.statusCode, 204);
      expect(
        preflight.headers['access-control-allow-origin'],
        'https://geriogerg.github.io',
      );
      expect(
        preflight.headers['access-control-allow-headers'],
        contains('authorization'),
      );
      final get = await send('GET', '/health', headers: origin);
      expect(
        get.headers['access-control-allow-origin'],
        'https://geriogerg.github.io',
      );
    });

    test('a pattern: one label, letters, digits and dashes only', () {
      const staging = {'https://math-trainer-staging*.pages.dev'};
      for (final ok in [
        'https://math-trainer-staging.pages.dev',
        'https://math-trainer-staging-x7q.pages.dev',
      ]) {
        expect(originAllowed(ok, staging), isTrue, reason: ok);
      }
      for (final no in [
        'https://math-trainer-staging.evil.dev/x.pages.dev',
        'https://math-trainer-staging.x.pages.dev',
        'https://abc.math-trainer-staging.pages.dev',
        'http://math-trainer-staging.pages.dev',
        'https://math-trainer.pages.dev',
      ]) {
        expect(originAllowed(no, staging), isFalse, reason: no);
      }
      expect(originAllowed('https://a.b', {'https://a.b'}), isTrue);
      expect(originAllowed('https://axb', {'https://a.b'}), isFalse);
    });

    test('another origin gets none', () async {
      final response = await send(
        'GET',
        '/health',
        headers: {'origin': 'https://evil.example'},
      );
      expect(response.headers['access-control-allow-origin'], isNull);
      expect(response.headers['vary'], 'Origin');
    });
  });
}
