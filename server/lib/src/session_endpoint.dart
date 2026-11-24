import 'dart:convert';

import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:shelf/shelf.dart';

import 'http_app.dart';
import 'supabase_gateway.dart';

/// Largest accepted body: a 24-question session is about 6 KB; the longest
/// game (4 operations × 20 questions) about 20 KB.
const maxUploadBytes = 256 * 1024;

/// `POST /v1/sessions` (plan, Phase 2 commits 5 and 6): one uploaded
/// session, replayed and validated, idempotent on its id. Answers:
/// - 200 `{status: accepted, syncedAt, duplicate}` — stored now or before;
/// - 400 / 409 `{status: refused, reason}` — malformed or refused for good:
///   the app records it and never resends;
/// - 401 no or bad token, 413 too large, 503 Supabase unavailable: the app
///   retries later;
/// - 403 `{error: beta_code_required}` ([requireBetaCode]): an anonymous
///   player who never redeemed an invitation code and has nothing accepted
///   yet. Not a refusal: the app keeps the session and retries, so a tester
///   whose code is redeemed later loses nothing.
class SessionEndpoint {
  SessionEndpoint(
    this.gateway, {
    DateTime Function()? clock,
    this.requireBetaCode = false,
  }) : _clock = clock ?? DateTime.now;

  final SupabaseGateway gateway;
  final DateTime Function() _clock;

  /// The invite-only beta, enforced here too (Phase 5.1 commit 5): the app's
  /// gate is a screen, and the API is reachable without it. Linked
  /// (email) accounts pass; so does any player with an invitation code or
  /// an accepted session (`upload_allowed`, SQL) — the testers already in.
  final bool requireBetaCode;

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
    } on GatewayUnavailable catch (e) {
      return _unavailable(e);
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
      if (requireBetaCode && user.isAnonymous) {
        final allowed = await gateway.rpc('upload_allowed', {
          'p_player_id': user.id,
        });
        if (allowed != true) {
          return jsonResponse(403, {'error': 'beta_code_required'});
        }
      }
      return await store(upload, receivedAt: _clock().toUtc());
    } on GatewayUnavailable catch (e) {
      return _unavailable(e);
    }
  }

  /// The app only sees 503 and retries; the reason (which call, Supabase's
  /// status and the start of its answer — never a key or token) goes to the
  /// host's logs. Without it a server that can never write looks like a
  /// sleeping one (staging, 23 Nov 2026: a key without the service role).
  Response _unavailable(GatewayUnavailable e) {
    // ignore: avoid_print
    print('503 on POST /v1/sessions: ${e.detail}');
    return jsonResponse(503, {'error': 'unavailable'});
  }

  /// Decides [upload] once and for all (plan 6.4): an id already decided
  /// gets the same answer again (idempotence); otherwise the server reads
  /// the player's state, replays the session with math_core
  /// (`validateSessionUpload`) and applies or records the verdict. A
  /// concurrent upload of the same player makes the apply "stale": read
  /// and validate again, up to [maxAttempts] times.
  Future<Response> store(
    SessionUpload upload, {
    required DateTime receivedAt,
  }) async {
    final session = upload.session;
    final known = _rows(
      await gateway.rpc('upload_status', {'p_session_id': session.id}),
    );
    if (known.isNotEmpty) {
      final row = known.first;
      if (row['player_id'] != session.playerId) {
        return refused(409, 'idConflict');
      }
      if (row['state'] == 'accepted') {
        return accepted(row['received_at'], duplicate: true);
      }
      return refused(409, '${row['reason']}');
    }

    // A game holding weak spots: were they due? Its accepted history, read
    // once (Phase 4 close-out). Never a refusal: a flag.
    final history = needsUploadHistory(session)
        ? parseUploadHistory(
            await gateway.rpc('player_upload_history', {
              'p_player_id': session.playerId,
            }),
          )
        : null;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final (version, state) = parseServerState(
        await gateway.rpc('player_server_state', {
          'p_player_id': session.playerId,
        }),
      );
      final verdict = validateSessionUpload(
        upload: upload,
        callerId: session.playerId,
        state: state,
        receivedAt: receivedAt,
        history: history,
      );
      switch (verdict) {
        case Rejected(:final reason, :final detail):
          await gateway.rpc('record_rejected_upload', {
            'p_session_id': session.id,
            'p_player_id': session.playerId,
            'p_reason': reason.name,
            'p_detail': detail,
            'p_payload': upload.toJson(),
          });
          return refused(
            409,
            reason.name,
            // The app adopts these so its next games chain again.
            levels: reason == RejectionReason.levelsMismatch
                ? levelCacheToJson(state.levels)
                : null,
          );
        case Accepted(:final completed, :final levelUpdates, :final flags):
          final row = _rows(
            await gateway.rpc('apply_validated_session', {
              'p_session_id': session.id,
              'p_player_id': session.playerId,
              'p_expected_version': version,
              'p_created_at': session.createdAt.toIso8601String(),
              'p_kind': session.kind.name,
              'p_completed': completed,
              'p_payload': upload.toJson(),
              'p_level_updates': levelCacheToJson(levelUpdates),
              'p_flags': [for (final f in flags) f.name],
            }),
          ).first;
          switch (row['outcome']) {
            case 'applied':
              return accepted(row['received_at']);
            case 'duplicate':
              return accepted(row['received_at'], duplicate: true);
            case 'conflict':
              return refused(409, 'idConflict');
            case 'stale':
              continue;
          }
          throw StateError('apply_validated_session: ${row['outcome']}');
      }
    }
    // The player's state kept moving: let the app retry later.
    return jsonResponse(503, {'error': 'busy'});
  }

  static const maxAttempts = 3;
}

Response accepted(Object? receivedAt, {bool duplicate = false}) => jsonResponse(
  200,
  {'status': 'accepted', 'syncedAt': receivedAt, 'duplicate': duplicate},
);

/// `player_upload_history`'s JSON (accepted payloads, oldest first) as
/// stored games. A payload that no longer reads is left out: it was
/// accepted by an older server, and the check is only a flag.
List<StoredGame> parseUploadHistory(Object? json) {
  if (json is! List) throw StateError('player_upload_history: $json');
  final games = <StoredGame>[];
  for (final payload in json) {
    try {
      final upload = SessionUpload.fromJson(payload);
      games.add((session: upload.session, answers: upload.answers));
    } on FormatException {
      // Skipped.
    }
  }
  return games;
}

/// `player_server_state`'s JSON as (version, math_core state).
(int, ServerPlayerState) parseServerState(Object? json) {
  if (json is! Map) throw StateError('player_server_state: $json');
  final version = json['version'];
  final last = json['lastSessionAt'];
  if (version is! int) throw StateError('player_server_state: version');
  return (
    version,
    ServerPlayerState(
      levels: levelCacheFromJson(json['levels'] ?? const {}),
      lastSessionAt: last == null ? null : DateTime.parse('$last').toUtc(),
      hasCompletedSession: json['hasCompletedSession'] == true,
    ),
  );
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

List<Map<String, Object?>> _rows(Object? result) => switch (result) {
  final List<Object?> list => [
    for (final row in list)
      if (row is Map) row.cast<String, Object?>(),
  ],
  final Map<Object?, Object?> row => [row.cast<String, Object?>()],
  _ => const [],
};
