import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' show Request;

import 'config.dart';

/// The player a bearer token belongs to. [isGuest]: anonymous, or an email
/// never confirmed (Phase 6c commit 3, review B2) — no online play, no
/// board, whatever the account says it is.
typedef AuthenticatedUser = ({String id, bool isGuest});

/// Supabase could not answer now (network, 5xx): the caller answers 503
/// and the app retries.
class GatewayUnavailable implements Exception {
  const GatewayUnavailable(this.detail);
  final String detail;
  @override
  String toString() => 'GatewayUnavailable: $detail';
}

/// Supabase refused the call itself (PostgREST 4xx: a value the database
/// cannot take, such as an id that is not a UUID): deciding again will not
/// change it, so the endpoints answer 400 `badRequest` — final for the app
/// (Phase 6a, review m2). A 503 here kept one session failing for ever.
class GatewayRejected implements Exception {
  const GatewayRejected(this.detail);
  final String detail;
  @override
  String toString() => 'GatewayRejected: $detail';
}

/// Whether [value] is a UUID (any version): what every id column takes.
bool isUuid(Object? value) => value is String && _uuid.hasMatch(value);

/// Everything the server asks of Supabase. Tests use a fake; the real one
/// speaks HTTP ([HttpSupabaseGateway]).
abstract interface class SupabaseGateway {
  /// The user of [accessToken], checked by Supabase Auth itself (signature,
  /// expiry, revocation); `null` if it is not a valid token.
  Future<AuthenticatedUser?> userForToken(String accessToken);

  /// Calls the database function [name] as the service role (bypasses
  /// row-level security; the functions are granted to `service_role` only).
  /// Returns its decoded JSON result.
  Future<Object?> rpc(String name, Map<String, Object?> params);
}

/// The caller of [request], from its `Authorization: Bearer` token checked
/// by Supabase Auth; `null` without a token or with an invalid one (the
/// endpoints answer 401). Throws [GatewayUnavailable] like the gateway.
Future<AuthenticatedUser?> bearerUser(
  SupabaseGateway gateway,
  Request request,
) async {
  final authorization = request.headers['authorization'] ?? '';
  if (!authorization.startsWith('Bearer ')) return null;
  return gateway.userForToken(authorization.substring(7));
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Whether [token] can be a Supabase access token at all: a JWT whose
/// payload names a user id and an expiry not yet passed (a minute's grace
/// for clocks). Nothing is verified — Supabase Auth does that — but what
/// fails here is refused without calling it (review B4: any `Bearer x`
/// cost an outbound request).
bool looksLikeAccessToken(String token, {DateTime? now}) {
  if (token.length > 4096) return false;
  final parts = token.split('.');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map) return false;
    final subject = payload['sub'];
    final expiry = payload['exp'];
    if (subject is! String || !_uuid.hasMatch(subject)) return false;
    if (expiry is! num) return false;
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return expiry + 60 > seconds;
  } on FormatException {
    return false;
  }
}

class HttpSupabaseGateway implements SupabaseGateway {
  HttpSupabaseGateway(this.config, {http.Client? client})
    : _client = client ?? http.Client();

  final ServerConfig config;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  /// New-style secret keys (`sb_secret_…`) go in `apikey` only; a legacy
  /// service-role JWT also as the bearer.
  Map<String, String> get _keyHeaders => {
    'apikey': config.supabaseSecretKey,
    if (!config.supabaseSecretKey.startsWith('sb_'))
      'authorization': 'Bearer ${config.supabaseSecretKey}',
  };

  @override
  Future<AuthenticatedUser?> userForToken(String accessToken) async {
    if (!looksLikeAccessToken(accessToken)) return null;
    final response = await _send(
      () => _client.get(
        config.supabaseUrl.resolve('/auth/v1/user'),
        headers: {
          'apikey': config.supabaseSecretKey,
          'authorization': 'Bearer $accessToken',
        },
      ),
    );
    if (response.statusCode == 401 || response.statusCode == 403) return null;
    if (response.statusCode != 200) {
      throw GatewayUnavailable('auth HTTP ${response.statusCode}');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['id'] is! String) {
      throw const GatewayUnavailable('auth: unexpected body');
    }
    return (
      id: body['id'] as String,
      isGuest:
          body['is_anonymous'] == true || body['email_confirmed_at'] == null,
    );
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) async {
    final response = await _send(
      () => _client.post(
        config.supabaseUrl.resolve('/rest/v1/rpc/$name'),
        headers: {..._keyHeaders, 'content-type': 'application/json'},
        body: jsonEncode(params),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The body names the SQL error; it holds no secret, but may hold
      // request data: only its start is kept, for the host's logs.
      final start = response.body.length > 200
          ? response.body.substring(0, 200)
          : response.body;
      final detail = 'rpc $name HTTP ${response.statusCode}: $start';
      // 4xx: the database refused these values — except what means "not
      // now" (the key, a timeout, a rate limit) or a missing function (an
      // older database: a deploy order problem, retried).
      final status = response.statusCode;
      if (status >= 400 &&
          status < 500 &&
          !const {401, 403, 404, 408, 429}.contains(status)) {
        throw GatewayRejected(detail);
      }
      throw GatewayUnavailable(detail);
    }
    return response.body.isEmpty ? null : jsonDecode(response.body);
  }

  Future<http.Response> _send(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw const GatewayUnavailable('timeout');
    } on http.ClientException catch (e) {
      throw GatewayUnavailable('network: ${e.message}');
    }
  }
}
