import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart' show Request;

import 'config.dart';

/// The player a bearer token belongs to.
typedef AuthenticatedUser = ({String id, bool isAnonymous});

/// Supabase could not answer now (network, 5xx): the caller answers 503
/// and the app retries.
class GatewayUnavailable implements Exception {
  const GatewayUnavailable(this.detail);
  final String detail;
  @override
  String toString() => 'GatewayUnavailable: $detail';
}

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
      isAnonymous: body['is_anonymous'] == true,
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
      throw GatewayUnavailable('rpc $name HTTP ${response.statusCode}: $start');
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
