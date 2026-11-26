import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';
import 'session_endpoint_test.dart' show FakeGateway, honest;

/// Phase 6a commit 2 (plan v3.9; review B4): the floor under abuse — rate
/// limits, bodies cut while read, tokens that cannot be tokens refused
/// without calling Supabase, daily caps.
void main() {
  final config = ServerConfig(
    supabaseUrl: Uri.parse('https://example.supabase.co'),
    supabaseSecretKey: 'sb_secret_test',
    allowedOrigins: const {'https://app.example'},
  );

  /// A token shaped like Supabase's: header.payload.signature.
  String jwt(Map<String, Object?> payload) {
    String part(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'HS256'})}.${part(payload)}.c2lnbmF0dXJl';
  }

  const someone = '11111111-2222-4333-8444-555555555555';
  int inAnHour() =>
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;

  group('TokenBuckets', () {
    test('a burst up to the capacity, then one token per refill', () {
      var now = DateTime.utc(2026, 11, 26, 12);
      final buckets = TokenBuckets(
        capacity: 3,
        refillPerSecond: 0.5,
        clock: () => now,
      );
      expect(
        [for (var i = 0; i < 3; i++) buckets.take('a')],
        [null, null, null],
      );
      expect(buckets.take('a'), const Duration(seconds: 2));
      expect(buckets.take('b'), isNull, reason: 'another key, its own tokens');
      now = now.add(const Duration(seconds: 1));
      expect(buckets.take('a'), const Duration(seconds: 1), reason: 'half');
      now = now.add(const Duration(seconds: 1));
      expect(buckets.take('a'), isNull);
      expect(buckets.take('a'), isNotNull);
      // A long rest refills to the capacity, never beyond.
      now = now.add(const Duration(hours: 1));
      expect(
        [for (var i = 0; i < 4; i++) buckets.take('a') == null],
        [true, true, true, false],
      );
    });

    test('a flood of keys does not grow the map without limit', () {
      var now = DateTime.utc(2026, 11, 26, 12);
      final buckets = TokenBuckets(
        capacity: 2,
        refillPerSecond: 1,
        clock: () => now,
        maxKeys: 100,
      );
      for (var i = 0; i < 5000; i++) {
        buckets.take('key-$i');
        if (i % 50 == 0) now = now.add(const Duration(seconds: 1));
      }
      expect(buckets.keys, lessThanOrEqualTo(101));
      // With no time passing at all, the oldest half goes.
      for (var i = 0; i < 1000; i++) {
        buckets.take('late-$i');
      }
      expect(buckets.keys, lessThanOrEqualTo(101));
    });

    test('invalid settings throw', () {
      expect(
        () => TokenBuckets(capacity: 0, refillPerSecond: 1),
        throwsArgumentError,
      );
      expect(
        () => TokenBuckets(capacity: 1, refillPerSecond: 0),
        throwsArgumentError,
      );
    });
  });

  group('per address, before any work', () {
    late int reached;
    late Handler handler;

    setUp(() {
      reached = 0;
      handler = buildHandler(
        config,
        limits: RateLimits(
          perAddress: TokenBuckets(capacity: 3, refillPerSecond: 0.01),
        ),
        routes: [
          (
            method: 'POST',
            path: '/v1/sessions',
            handler: (_) {
              reached++;
              return jsonResponse(200, {'ok': true});
            },
          ),
        ],
      );
    });

    Future<Response> call(
      String path, {
      String method = 'POST',
      Map<String, String> headers = const {},
    }) async => handler(
      Request(method, Uri.parse('http://localhost$path'), headers: headers),
    );

    test('the fourth request of an address in a burst is a 429 the app '
        'can read, and nothing ran', () async {
      const from = {
        'x-forwarded-for': '203.0.113.7, 10.0.0.1',
        'origin': 'https://app.example',
      };
      for (var i = 0; i < 3; i++) {
        expect((await call('/v1/sessions', headers: from)).statusCode, 200);
      }
      final limited = await call('/v1/sessions', headers: from);
      expect(limited.statusCode, 429);
      expect(jsonDecode(await limited.readAsString()), {
        'error': 'rate_limited',
      });
      expect(int.parse(limited.headers['retry-after']!), greaterThan(0));
      expect(
        limited.headers['access-control-allow-origin'],
        'https://app.example',
        reason: 'the browser lets the app see the status',
      );
      expect(reached, 3);
      // Unknown paths count too; another address is not affected; /health
      // and a preflight never count.
      expect((await call('/nowhere', headers: from)).statusCode, 429);
      expect(
        (await call(
          '/v1/sessions',
          headers: {'x-forwarded-for': '203.0.113.8'},
        )).statusCode,
        200,
      );
      for (var i = 0; i < 10; i++) {
        expect(
          (await call('/health', method: 'GET', headers: from)).statusCode,
          200,
        );
        expect(
          (await call(
            '/v1/sessions',
            method: 'OPTIONS',
            headers: from,
          )).statusCode,
          204,
        );
      }
    });

    test('the address: the proxy\'s header, the first forwarded entry, '
        'a bounded key', () {
      Request request(Map<String, String> headers) =>
          Request('POST', Uri.parse('http://localhost/x'), headers: headers);
      expect(
        clientAddress(
          request({
            'cf-connecting-ip': '198.51.100.4',
            'x-forwarded-for': '203.0.113.7',
          }),
        ),
        '198.51.100.4',
      );
      expect(
        clientAddress(request({'x-forwarded-for': ' 203.0.113.7 , 10.0.0.1'})),
        '203.0.113.7',
      );
      expect(clientAddress(request(const {})), 'unknown');
      expect(
        clientAddress(request({'x-forwarded-for': 'a' * 5000})),
        hasLength(64),
      );
    });
  });

  group('bodies are counted while read', () {
    /// A body of [chunks] chunks of 1,000 bytes with no declared length;
    /// [sent] counts the chunks actually pulled.
    Request chunked(int chunks, void Function() sent, {String? token}) =>
        Request(
          'POST',
          Uri.parse('http://localhost/v1/sessions'),
          headers: {'authorization': ?(token == null ? null : 'Bearer $token')},
          body: () async* {
            for (var i = 0; i < chunks; i++) {
              sent();
              yield List.filled(1000, 0x61);
            }
          }(),
        );

    test('a body past the cap is given up at once, not read whole', () async {
      var pulled = 0;
      final text = await readBodyWithin(chunked(5000, () => pulled++), 10000);
      expect(text, isNull);
      expect(pulled, lessThanOrEqualTo(12), reason: '$pulled chunks read');
      var small = 0;
      expect(
        await readBodyWithin(chunked(4, () => small++), 10000),
        'a' * 4000,
      );
      // A declared length past the cap: not read at all.
      final declared = Request(
        'POST',
        Uri.parse('http://localhost/x'),
        body: 'x' * 20000,
      );
      expect(await readBodyWithin(declared, 10000), isNull);
    });

    test('POST /v1/sessions with an endless chunked body: 413', () async {
      final gateway = FakeGateway()
        ..users['token-p1'] = (id: 'p1', isAnonymous: true);
      final handler = buildHandler(
        config,
        routes: [SessionEndpoint(gateway).route],
      );
      var pulled = 0;
      final response = await handler(
        chunked(100000, () => pulled++, token: 'token-p1'),
      );
      expect(response.statusCode, 413);
      expect(pulled, lessThan(300), reason: 'cut at 256 KB: $pulled KB read');
      expect(gateway.calls, isEmpty);
    });

    test('POST /v1/duels/run likewise', () async {
      final gateway = FakeDuelGateway()..addUser('tok-a', 'ana');
      final handler = buildHandler(
        config,
        routes: DuelEndpoint(gateway).routes,
      );
      var pulled = 0;
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/duels/run'),
          headers: {'authorization': 'Bearer tok-a'},
          body: () async* {
            for (var i = 0; i < 100000; i++) {
              pulled++;
              yield List.filled(1000, 0x61);
            }
          }(),
        ),
      );
      expect(response.statusCode, 413);
      expect(pulled, lessThan(80), reason: 'cut at 64 KB: $pulled KB read');
    });
  });

  group('a token that cannot be one never reaches Supabase', () {
    test('looksLikeAccessToken', () {
      final good = jwt({'sub': someone, 'exp': inAnHour()});
      expect(looksLikeAccessToken(good), isTrue);
      expect(looksLikeAccessToken('x'), isFalse);
      expect(looksLikeAccessToken(''), isFalse);
      expect(looksLikeAccessToken('a.b.c'), isFalse);
      expect(looksLikeAccessToken('$good.extra'), isFalse);
      expect(
        looksLikeAccessToken(jwt({'sub': 'not-a-uuid', 'exp': inAnHour()})),
        isFalse,
      );
      expect(looksLikeAccessToken(jwt({'sub': someone})), isFalse);
      expect(
        looksLikeAccessToken(jwt({'sub': someone, 'exp': 1700000000})),
        isFalse,
        reason: 'expired',
      );
      expect(
        looksLikeAccessToken(
          jwt({'sub': someone, 'exp': 1700000000}),
          now: DateTime.fromMillisecondsSinceEpoch(1700000030 * 1000),
        ),
        isTrue,
        reason: 'a minute of grace for clocks',
      );
      expect(looksLikeAccessToken('${'a' * 5000}.b.c'), isFalse);
    });

    test('the gateway: no request for garbage, one for a real shape; its '
        'answers', () async {
      final requests = <http.Request>[];
      var status = 200;
      Object body = {'id': someone, 'is_anonymous': true};
      final gateway = HttpSupabaseGateway(
        config,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(jsonEncode(body), status);
        }),
      );
      for (final garbage in ['x', 'a.b.c', '', 'Bearer', '${'z' * 300}.y.x']) {
        expect(await gateway.userForToken(garbage), isNull);
      }
      expect(requests, isEmpty, reason: 'nothing left the server');

      final token = jwt({'sub': someone, 'exp': inAnHour()});
      expect(await gateway.userForToken(token), (
        id: someone,
        isAnonymous: true,
      ));
      expect(requests.single.url.path, '/auth/v1/user');
      expect(requests.single.headers['authorization'], 'Bearer $token');
      expect(requests.single.headers['apikey'], 'sb_secret_test');
      status = 401;
      expect(await gateway.userForToken(token), isNull, reason: 'forged');
      status = 500;
      expect(
        () => gateway.userForToken(token),
        throwsA(isA<GatewayUnavailable>()),
      );
      status = 200;
      body = ['not', 'a', 'user'];
      expect(
        () => gateway.userForToken(token),
        throwsA(isA<GatewayUnavailable>()),
      );
    });

    test('the gateway\'s database calls: the key, the JSON, a failure '
        'with its status', () async {
      final requests = <http.Request>[];
      var status = 200;
      var answer = '{"outcome":"applied"}';
      final gateway = HttpSupabaseGateway(
        config,
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(answer, status);
        }),
      );
      expect(await gateway.rpc('apply', {'p_a': 1}), {'outcome': 'applied'});
      final sent = requests.single;
      expect(sent.url.path, '/rest/v1/rpc/apply');
      expect(sent.headers['apikey'], 'sb_secret_test');
      expect(
        sent.headers.containsKey('authorization'),
        isFalse,
        reason: 'a new-style secret key goes in apikey only',
      );
      expect(jsonDecode(sent.body), {'p_a': 1});
      answer = '';
      expect(await gateway.rpc('nothing', const {}), isNull);
      status = 404;
      answer = '{"message":"${'no such function ' * 40}"}';
      await expectLater(
        gateway.rpc('missing', const {}),
        throwsA(
          isA<GatewayUnavailable>()
              .having(
                (e) => e.detail,
                'detail',
                startsWith('rpc missing HTTP 404'),
              )
              .having((e) => e.detail.length, 'kept short', lessThan(260)),
        ),
      );
    });
  });

  group('per player', () {
    test('requests past the player\'s bucket are 429 before any database '
        'call; another player is not affected', () async {
      final gateway = FakeGateway()
        ..users['token-p1'] = (id: 'p1', isAnonymous: true)
        ..users['token-p2'] = (id: 'p2', isAnonymous: true);
      final handler = buildHandler(
        config,
        routes: [
          SessionEndpoint(
            gateway,
            clock: () => DateTime.utc(2026, 11, 20, 10),
            limits: RateLimits(
              perPlayer: TokenBuckets(capacity: 2, refillPerSecond: 0.01),
            ),
          ).route,
        ],
      );
      Future<Response> post(String token, Object body) async => handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/sessions'),
          headers: {'authorization': 'Bearer $token'},
          body: jsonEncode(body),
        ),
      );
      expect((await post('token-p1', honest('s1').toJson())).statusCode, 200);
      expect((await post('token-p1', {'junk': 1})).statusCode, 400);
      gateway.calls.clear();
      final limited = await post('token-p1', honest('s2').toJson());
      expect(limited.statusCode, 429);
      expect(jsonDecode(await limited.readAsString()), {
        'error': 'rate_limited',
      });
      expect(gateway.calls, isEmpty);
      expect(
        (await post(
          'token-p2',
          honest('s3', player: 'p2').toJson(),
        )).statusCode,
        200,
      );
    });

    test('the daily cap on accepted sessions: 429, nothing decided — the '
        'app keeps the session', () async {
      final gateway = FakeGateway()
        ..users['token-p1'] = (id: 'p1', isAnonymous: true)
        ..acceptedToday['p1'] = maxSessionsPerDay;
      final handler = buildHandler(
        config,
        routes: [
          SessionEndpoint(
            gateway,
            clock: () => DateTime.utc(2026, 11, 20, 10),
          ).route,
        ],
      );
      Future<Response> post() async => handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/sessions'),
          headers: {'authorization': 'Bearer token-p1'},
          body: jsonEncode(honest('s1').toJson()),
        ),
      );
      final capped = await post();
      expect(capped.statusCode, 429);
      expect(jsonDecode(await capped.readAsString()), {'error': 'daily_limit'});
      expect(gateway.accepted, isEmpty);
      expect(gateway.rejected, isEmpty);
      gateway.acceptedToday['p1'] = maxSessionsPerDay - 1;
      expect((await post()).statusCode, 200);
    });

    test('the daily cap on new duels: 429; the duel still open is handed '
        'back', () async {
      final gateway = FakeDuelGateway()..addUser('tok-a', 'ana', name: 'Ana');
      var ids = 0;
      final handler = buildHandler(
        config,
        routes: DuelEndpoint(gateway, newId: () => 'duel-${++ids}').routes,
      );
      Future<Response> find(String mode) async => handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/duels'),
          headers: {'authorization': 'Bearer tok-a'},
          body: jsonEncode({'mode': mode}),
        ),
      );
      final first = await find('basics');
      expect(first.statusCode, 200);
      final offer = jsonDecode(await first.readAsString()) as Map;
      gateway.duelsToday['ana'] = maxDuelsPerDay;
      final again = await find('basics');
      expect(again.statusCode, 200, reason: 'the open one, not a new one');
      expect(
        (jsonDecode(await again.readAsString()) as Map)['duelId'],
        offer['duelId'],
      );
      final capped = await find('advanced');
      expect(capped.statusCode, 429);
      expect(jsonDecode(await capped.readAsString()), {'error': 'daily_limit'});
      expect(gateway.duels, hasLength(1));
    });
  });
}
