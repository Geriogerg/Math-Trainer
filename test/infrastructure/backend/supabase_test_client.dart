import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testUserId = '11111111-1111-4111-8111-111111111111';
const testEmail = 'player@test.com';

/// An unsigned but well-formed JWT: gotrue reads `exp` from the payload
/// (`Session.expiresAt`) without ever checking the signature client-side.
String _fakeAccessToken() {
  String encode(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': testUserId, 'exp': exp, 'role': 'authenticated'})}.'
      'signature';
}

Map<String, Object?> _sessionJson() => {
  'access_token': _fakeAccessToken(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-token',
  'user': {
    'id': testUserId,
    'email': testEmail,
    'aud': 'authenticated',
    'app_metadata': <String, Object>{},
    'user_metadata': <String, Object>{},
    'created_at': '2026-11-17T00:00:00Z',
  },
};

/// What Supabase Auth answers to an anonymous sign-in: same shape, an
/// empty email and `is_anonymous: true`.
Map<String, Object?> anonymousSessionJson() => {
  ..._sessionJson(),
  'user': {
    ...(_sessionJson()['user']! as Map<String, Object?>),
    'email': '',
    'is_anonymous': true,
  },
};

/// A real `SupabaseClient` (the app's code) with only the HTTP transport
/// simulated: sign-in and sign-out answer like Supabase Auth, and
/// [restHandler] answers PostgREST requests (`/rest/v1/...`). Each PostgREST
/// request received is added to [restRequests]. [authHandler], if given,
/// answers Auth requests first (sign-in, sign-up, sign-out) — to simulate a
/// server refusal or a network failure (throw an exception); `null` keeps
/// the default answer.
class SupabaseTestClient {
  SupabaseTestClient({
    Future<http.Response> Function(http.Request request)? restHandler,
    Future<http.Response?> Function(http.Request request)? authHandler,
  }) {
    client = SupabaseClient(
      'https://test-project.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.startsWith('/auth/v1/')) authRequests.add(request);
        if (authHandler != null && path.startsWith('/auth/v1/')) {
          final response = await authHandler(request);
          if (response != null) return response;
        }
        if (path == '/auth/v1/token') {
          return http.Response(
            jsonEncode(_sessionJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/auth/v1/logout') return http.Response('', 204);
        if (path.startsWith('/rest/v1/') && restHandler != null) {
          restRequests.add(request);
          final response = await restHandler(request);
          // PostgREST reads `response.request` to choose how to decode the
          // body — a `MockClient` does not set it by itself.
          return http.Response.bytes(
            response.bodyBytes,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }
        return http.Response('not simulated: ${request.method} $path', 500);
      }),
      // `implicit`: the default PKCE flow needs storage for the code
      // verifier as early as `signUp` (the app gets it from
      // `Supabase.initialize`). Only the email confirmation link depends on
      // it — outside the scope of these tests.
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }

  late final SupabaseClient client;
  final restRequests = <http.Request>[];

  /// Every Auth request received, in order.
  final authRequests = <http.Request>[];

  /// Reproduces what `Supabase.initialize` does at app start without a
  /// persisted session: an `initialSession` event without a session, which
  /// then stays at the head of the history replayed by `onAuthStateChange`.
  void emitInitialSessionWithoutUser() {
    // ignore: invalid_use_of_internal_member
    client.auth.notifyAllSubscribers(AuthChangeEvent.initialSession);
  }

  Future<void> signIn() => client.auth.signInWithPassword(
    email: testEmail,
    password: 'mot-de-passe',
  );
}
