import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';
import 'session_endpoint_test.dart' show honest;

/// Phase 6a commit 6 (plan v3.9; review m2, m10): what Supabase refuses is
/// refused for good, never "try again later"; abandoned duels are recorded
/// outside the requests.
void main() {
  final config = ServerConfig(
    supabaseUrl: Uri.parse('https://example.supabase.co'),
    supabaseSecretKey: 'sb_secret_test',
  );

  String jwt(String sub) {
    String part(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    return '${part({'alg': 'HS256'})}.${part({'sub': sub, 'exp': exp})}.c2ln';
  }

  const player = '11111111-2222-4333-8444-555555555555';

  group('a PostgREST 4xx is a final 400, a 5xx a 503', () {
    late int status;
    late List<String> calls;
    late Handler handler;

    setUp(() {
      status = 400;
      calls = [];
      final gateway = HttpSupabaseGateway(
        config,
        client: MockClient((request) async {
          if (request.url.path == '/auth/v1/user') {
            return http.Response(
              jsonEncode({'id': player, 'is_anonymous': true}),
              200,
            );
          }
          calls.add(request.url.pathSegments.last);
          return http.Response(
            jsonEncode({
              'code': '22P02',
              'message': 'invalid input syntax for type uuid: "s1"',
            }),
            status,
          );
        }),
      );
      handler = buildHandler(
        config,
        routes: [
          SessionEndpoint(
            gateway,
            clock: () => DateTime.utc(2026, 11, 20, 10),
          ).route,
        ],
      );
    });

    Future<(int, Map<String, Object?>)> upload() async {
      final logged = <String>[];
      final response = await runZoned(
        () => handler(
          Request(
            'POST',
            Uri.parse('http://localhost/v1/sessions'),
            headers: {'authorization': 'Bearer ${jwt(player)}'},
            body: jsonEncode(honest('s1', player: player).toJson()),
          ),
        ),
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, line) => logged.add(line),
        ),
      );
      return (
        response.statusCode,
        (jsonDecode(await response.readAsString()) as Map)
            .cast<String, Object?>(),
      );
    }

    test('a session id that is not a UUID: refused, never retried', () async {
      final (code, body) = await upload();
      expect(code, 400);
      expect(body['status'], 'refused');
      expect(body['reason'], 'badRequest');
      expect(calls, ['upload_status'], reason: 'the first call refused it');
    });

    test(
      'Supabase failing (5xx), or the key refused (401): 503, retried',
      () async {
        for (final failing in [500, 503, 401, 404]) {
          status = failing;
          final (code, body) = await upload();
          expect(
            (code, body['error']),
            (503, 'unavailable'),
            reason: '$failing',
          );
        }
      },
    );
  });

  group('abandoned duels, outside the requests', () {
    test('sweepSoon runs at most once a minute and never fails', () async {
      var now = DateTime.utc(2026, 11, 26, 12);
      final gateway = FakeDuelGateway();
      final endpoint = DuelEndpoint(
        gateway,
        sweepInRequests: false,
        clock: () => now,
      );
      endpoint.sweepSoon();
      await Future<void>.delayed(Duration.zero);
      endpoint.sweepSoon();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls.where((c) => c == 'duel_abandoned'), hasLength(1));
      now = now.add(const Duration(minutes: 2));
      gateway.down = true;
      endpoint.sweepSoon();
      await Future<void>.delayed(Duration.zero);
      expect(
        gateway.calls.where((c) => c == 'duel_abandoned'),
        hasLength(1),
        reason: 'Supabase down: nothing called, nothing thrown',
      );
    });

    test('a request no longer waits for the sweep', () async {
      final gateway = FakeDuelGateway()..addUser('tok-a', 'ana');
      final endpoint = DuelEndpoint(gateway, sweepInRequests: false);
      final handler = buildHandler(config, routes: endpoint.routes);
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/duels'),
          headers: {'authorization': 'Bearer tok-a'},
          body: jsonEncode({'mode': 'basics'}),
        ),
      );
      expect(response.statusCode, 200);
      expect(
        gateway.calls.first,
        isNot('duel_abandoned'),
        reason: 'the request was handled first',
      );
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, contains('duel_abandoned'));
    });
  });
}
