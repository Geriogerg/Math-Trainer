import 'dart:convert';

import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Records the reports; can be down.
class _Gateway implements SupabaseGateway {
  final reports = <Map<String, Object?>>[];
  bool down = false;

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) async {
    if (down) throw const GatewayUnavailable('down');
    expect(name, 'record_client_error');
    reports.add(params);
    return 'stored';
  }

  @override
  Future<AuthenticatedUser?> userForToken(String accessToken) =>
      throw StateError('a report needs no account');
}

/// Phase 6c commit 5 (plan v4.1): the app's error reports.
void main() {
  late _Gateway gateway;
  late Handler handler;

  setUp(() {
    gateway = _Gateway();
    handler = buildHandler(
      ServerConfig.fromEnvironment(const {
        'SUPABASE_URL': 'https://x.supabase.co',
        'SUPABASE_SECRET_KEY': 'sb_secret_x',
        'ALLOWED_ORIGINS': 'https://app.example',
      }),
      routes: [ErrorEndpoint(gateway).route],
    );
  });

  Future<Response> post(
    Object body, {
    String contentType = 'application/json',
    String address = '203.0.113.7',
  }) async => handler(
    Request(
      'POST',
      Uri.parse('http://localhost/v1/errors'),
      headers: {
        'content-type': contentType,
        'user-agent': 'Mozilla/5.0 (Android 14) Chrome/131',
        'cf-connecting-ip': address,
      },
      body: body is String ? body : jsonEncode(body),
    ),
  );

  test('stored without an account: the kind, the text, the version, the '
      'browser', () async {
    final response = await post({
      'kind': 'flutter',
      'message': 'Null check operator used on a null value',
      'stack': '#0 PlayTab.build (play_tab.dart:120)',
      'appVersion': 'e5c719e',
    });
    expect(response.statusCode, 202);
    expect(gateway.reports.single, {
      'p_kind': 'flutter',
      'p_message': 'Null check operator used on a null value',
      'p_stack': '#0 PlayTab.build (play_tab.dart:120)',
      'p_app_version': 'e5c719e',
      'p_user_agent': 'Mozilla/5.0 (Android 14) Chrome/131',
    });
  });

  test('tokens, keys and email addresses never stored; the text cut', () async {
    const jwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0In0.c2lnbmF0dXJlLXNpZ25hdHVyZQ';
    await post({
      'kind': 'zone',
      'message':
          'AuthException: refresh failed for ana@example.org with $jwt '
          '(apikey=sb_publishable_abcdef) Bearer abcdefgh12345678',
      'stack':
          'https://site.example/#access_token=xyz123&type=recovery\n'
          '${'#1 frame\n' * 1000}',
    });
    final stored = gateway.reports.single;
    final message = stored['p_message']! as String;
    for (final secret in [
      'ana@example.org',
      jwt,
      'sb_publishable_abcdef',
      'abcdefgh12345678',
    ]) {
      expect(message, isNot(contains(secret)));
    }
    expect(message, contains('<email>'));
    expect(message, contains('<token>'));
    final stack = stored['p_stack']! as String;
    expect(stack, isNot(contains('xyz123')));
    expect(stack, contains('access_token=<hidden>'));
    expect(stack.length, 4000);
  });

  test('sent as text by the loading page (sendBeacon): read alike; an '
      'unknown kind is "other"', () async {
    final response = await post(
      jsonEncode({'kind': 'something', 'message': 'main.dart.js: 404'}),
      contentType: 'text/plain;charset=UTF-8',
    );
    expect(response.statusCode, 202);
    expect(gateway.reports.single['p_kind'], 'other');
    expect(gateway.reports.single['p_app_version'], isNull);
  });

  test('refused: not JSON, no message, too large', () async {
    expect((await post('nope')).statusCode, 400);
    expect((await post({'kind': 'zone'})).statusCode, 400);
    expect((await post({'message': '   '})).statusCode, 400);
    expect((await post({'message': 'x' * 20000})).statusCode, 413);
    expect(gateway.reports, isEmpty);
  });

  test('10 an address, then one every six minutes', () async {
    for (var i = 0; i < 10; i++) {
      expect((await post({'message': 'e$i'})).statusCode, 202);
    }
    final limited = await post({'message': 'one more'});
    expect(limited.statusCode, 429);
    expect(int.parse(limited.headers['retry-after']!), greaterThan(300));
    expect(
      (await post({
        'message': 'elsewhere',
      }, address: '198.51.100.9')).statusCode,
      202,
    );
    expect(gateway.reports, hasLength(11));
  });

  test('the database down: 503, nothing more', () async {
    gateway.down = true;
    expect((await post({'message': 'lost'})).statusCode, 503);
  });
}
