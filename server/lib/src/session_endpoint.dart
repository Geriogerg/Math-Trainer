import 'dart:convert';

import 'package:math_core/sync/session_upload.dart';
import 'package:shelf/shelf.dart';

import 'http_app.dart';
import 'supabase_gateway.dart';

/// Largest accepted body: a 24-question session is about 6 KB.
const maxUploadBytes = 256 * 1024;

/// `POST /v1/sessions` (plan, Phase 2 commit 5): one uploaded session,
/// idempotent on its id. Answers:
/// - 200 `{status: accepted, syncedAt, duplicate}` — stored now or before;
/// - 400 / 409 `{status: refused, reason}` — malformed or refused for good:
///   the app records it and never resends;
/// - 401 no or bad token, 413 too large, 503 Supabase unavailable: the app
///   retries later.
class SessionEndpoint {
  SessionEndpoint(this.gateway, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SupabaseGateway gateway;
  final DateTime Function() _clock;

  Route get route => (method: 'POST', path: '/v1/sessions', handler: handle);

  Future<Response> handle(Request request) async {
    final authorization = request.headers['authorization'] ?? '';
    if (!authorization.startsWith('Bearer ')) {
      return jsonResponse(401, {'error': 'unauthorized'});
    }
    final length = request.contentLength;
    if (length != null && length > maxUploadBytes) {
      return jsonResponse(413, {'error': 'too_large'});
    }

    final AuthenticatedUser? user;
    try {
      user = await gateway.userForToken(authorization.substring(7));
    } on GatewayUnavailable {
      return jsonResponse(503, {'error': 'unavailable'});
    }
    if (user == null) return jsonResponse(401, {'error': 'unauthorized'});

    final text = await request.readAsString();
    if (text.length > maxUploadBytes) {
      return jsonResponse(413, {'error': 'too_large'});
    }
    final SessionUpload upload;
    try {
      upload = SessionUpload.fromJson(jsonDecode(text));
    } on FormatException catch (e) {
      return refused(400, 'badRequest', detail: e.message);
    }
    if (upload.session.playerId != user.id) {
      return refused(409, 'wrongPlayer');
    }

    try {
      return await store(upload, receivedAt: _clock().toUtc());
    } on GatewayUnavailable {
      return jsonResponse(503, {'error': 'unavailable'});
    }
  }

  /// Records [upload] once (`record_session_upload`, idempotent on the id).
  Future<Response> store(
    SessionUpload upload, {
    required DateTime receivedAt,
  }) async {
    final session = upload.session;
    final result = await gateway.rpc('record_session_upload', {
      'p_session_id': session.id,
      'p_player_id': session.playerId,
      'p_created_at': session.createdAt.toIso8601String(),
      'p_kind': session.kind.name,
      'p_payload': upload.toJson(),
    });
    final row = _firstRow(result);
    switch (row['outcome']) {
      case 'inserted':
      case 'duplicate':
        return jsonResponse(200, {
          'status': 'accepted',
          'syncedAt': row['received_at'],
          'duplicate': row['outcome'] == 'duplicate',
        });
      case 'conflict':
        // The id is taken by another player's session: never this one's.
        return refused(409, 'idConflict');
    }
    throw StateError('record_session_upload answered ${row['outcome']}');
  }
}

/// A final refusal the app records and never resends.
Response refused(
  int status,
  String reason, {
  String? detail,
  Map<String, Object?>? levels,
}) => jsonResponse(status, {
  'status': 'refused',
  'reason': reason,
  'detail': ?detail,
  'levels': ?levels,
});

Map<String, Object?> _firstRow(Object? result) {
  final row = result is List && result.isNotEmpty ? result.first : result;
  if (row is! Map) throw StateError('unexpected rpc result: $result');
  return row.cast<String, Object?>();
}
