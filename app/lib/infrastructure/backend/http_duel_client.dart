import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';

/// The server's duel endpoints (Phase 7, `server/lib/src/duel_endpoint.dart`)
/// with the player's access token. Offline, timeouts, a server asleep or
/// down, a non-JSON page, an expired token: [DuelUnavailable] — try again.
/// Only the server's own refusal is [DuelRefused]; a guest gets
/// [DuelAccountRequired].
class HttpDuelClient implements DuelClient {
  HttpDuelClient({
    required this.serverUrl,
    required this.accessToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 90),
  }) : _client = client ?? http.Client();

  final Uri serverUrl;
  final Future<String?> Function() accessToken;
  final http.Client _client;

  /// Generous: a free host wakes up in about a minute.
  final Duration timeout;

  @override
  Future<DuelOffer> find(
    DuelMode mode, {
    String? rematchOf,
    String? challenge,
  }) async {
    final answer = await _post('/v1/duels', {
      'mode': mode.name,
      'rematchOf': ?rematchOf,
      'challenge': ?challenge,
      ...knownDuelRules(),
    });
    return _parse(() => DuelOffer.fromJson(_accepted(answer, offer: true)));
  }

  @override
  Future<DuelOffer> open(String duelId) async {
    final answer = await _post('/v1/duels/open', {
      'duelId': duelId,
      ...knownDuelRules(),
    });
    return _parse(() => DuelOffer.fromJson(_accepted(answer, offer: true)));
  }

  @override
  Future<DuelVerdict> submit(String duelId, DuelMode mode, DuelRun run) async {
    final answer = await _post('/v1/duels/run', {
      'duelId': duelId,
      'run': run.toJson(),
    });
    return _parse(() => DuelVerdict.fromJson(_accepted(answer), mode));
  }

  @override
  Future<void> progress(String duelId, DuelRun run) async {
    // Best effort: an older server (404), offline — nothing to do.
    try {
      await _post('/v1/duels/progress', {
        'duelId': duelId,
        'run': run.toJson(),
      });
    } on DuelUnavailable {
      return;
    }
  }

  @override
  Future<DuelServerSupport> support() async {
    final http.Response response;
    try {
      response = await _client
          .get(serverUrl.resolve('/health'))
          .timeout(timeout);
    } on TimeoutException {
      throw const DuelUnavailable('timeout');
    } on http.ClientException catch (e) {
      throw DuelUnavailable('network: ${e.message}');
    }
    Object? body;
    try {
      body = jsonDecode(response.body);
    } on FormatException {
      throw const DuelUnavailable('health: not JSON');
    }
    final modes = body is Map ? body['duelModes'] : null;
    final rules = body is Map ? body['duelRules'] : null;
    return (
      modes: {
        if (modes is List)
          for (final mode in DuelMode.values)
            if (modes.contains(mode.name)) mode,
      },
      rules: {
        if (rules is List)
          for (final v in rules)
            if (v is int) v,
      },
    );
  }

  /// The server's answer as JSON, `(status code, body)`.
  Future<(int, Object?)> _post(String path, Map<String, Object?> body) async {
    final token = await accessToken();
    if (token == null) throw const DuelUnavailable('not signed in');
    final http.Response response;
    try {
      response = await _client
          .post(
            serverUrl.resolve(path),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const DuelUnavailable('timeout');
    } on http.ClientException catch (e) {
      throw DuelUnavailable('network: ${e.message}');
    }
    try {
      return (response.statusCode, jsonDecode(response.body));
    } on FormatException {
      throw DuelUnavailable('HTTP ${response.statusCode}, not JSON');
    }
  }

  /// The body of a final, positive answer; throws for anything else. An
  /// offer has no `status` field: a 200 is enough.
  Object? _accepted((int, Object?) answer, {bool offer = false}) {
    final (status, body) = answer;
    if (body is Map && body['status'] == 'refused') {
      throw DuelRefused('${body['reason']}');
    }
    if (status == 403 && body is Map && body['error'] == 'account_required') {
      throw const DuelAccountRequired();
    }
    if (status != 200 || body is! Map) {
      throw DuelUnavailable('HTTP $status');
    }
    if (!offer && body['status'] != 'accepted') {
      throw DuelUnavailable('HTTP $status, no status');
    }
    return body;
  }

  /// A malformed body from our own server is not final either.
  T _parse<T>(T Function() read) {
    try {
      return read();
    } on FormatException catch (e) {
      throw DuelUnavailable('bad answer: ${e.message}');
    }
  }
}
