import 'dart:convert';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Tokens map to users; the database functions are an in-memory model of
/// the SQL ones (`supabase/migrations/…_server_validation.sql`, tested on
/// Postgres by `supabase/tests/20_server_validation_test.sql`).
class FakeGateway implements SupabaseGateway {
  final users = <String, AuthenticatedUser>{};
  final calls = <String>[];
  bool down = false;

  /// Bumps a player's version once, right before their next apply: another
  /// upload landed in between.
  final concurrentUploadFor = <String>{};

  final accepted = <String, ({String player, String receivedAt})>{};
  final rejected = <String, ({String player, String reason})>{};
  final versions = <String, int>{};
  final lastSessionAt = <String, String>{};
  final completed = <String>{};
  final levels = <String, Map<String, Object?>>{};
  final flags = <String, List<Object?>>{};

  /// Players who redeemed an invitation code (`beta_code_uses`).
  final withCode = <String>{};

  @override
  Future<AuthenticatedUser?> userForToken(String accessToken) async {
    if (down) throw const GatewayUnavailable('down');
    return users[accessToken];
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> p) async {
    if (down) throw const GatewayUnavailable('down');
    calls.add(name);
    switch (name) {
      case 'upload_status':
        final id = p['p_session_id'];
        if (accepted[id] case final a?) {
          return [
            {
              'state': 'accepted',
              'player_id': a.player,
              'received_at': a.receivedAt,
            },
          ];
        }
        if (rejected[id] case final r?) {
          return [
            {'state': 'rejected', 'player_id': r.player, 'reason': r.reason},
          ];
        }
        return [];
      case 'player_server_state':
        final player = p['p_player_id'] as String;
        return {
          'version': versions[player] ?? 0,
          'lastSessionAt': lastSessionAt[player],
          'hasCompletedSession': completed.contains(player),
          'levels': levels[player] ?? {},
        };
      case 'apply_validated_session':
        final id = p['p_session_id'] as String;
        final player = p['p_player_id'] as String;
        if (accepted[id] case final a?) {
          return [
            {
              'outcome': a.player == player ? 'duplicate' : 'conflict',
              'received_at': a.receivedAt,
            },
          ];
        }
        if (concurrentUploadFor.remove(player)) {
          versions[player] = (versions[player] ?? 0) + 1;
        }
        if ((versions[player] ?? 0) != p['p_expected_version']) {
          return [
            {'outcome': 'stale', 'received_at': null},
          ];
        }
        const at = '2026-11-20T10:00:00+00:00';
        accepted[id] = (player: player, receivedAt: at);
        levels[player] = {
          ...?levels[player],
          ...(p['p_level_updates'] as Map).cast<String, Object?>(),
        };
        flags[id] = p['p_flags'] as List<Object?>;
        versions[player] = (versions[player] ?? 0) + 1;
        lastSessionAt[player] = p['p_created_at'] as String;
        if (p['p_completed'] == true) completed.add(player);
        return [
          {'outcome': 'applied', 'received_at': at},
        ];
      case 'upload_allowed':
        final player = p['p_player_id'] as String;
        return withCode.contains(player) ||
            accepted.values.any((a) => a.player == player);
      case 'record_rejected_upload':
        rejected.putIfAbsent(
          p['p_session_id'] as String,
          () => (
            player: p['p_player_id'] as String,
            reason: p['p_reason'] as String,
          ),
        );
        return null;
    }
    throw StateError('unknown rpc $name');
  }
}

const _types = {ExerciseType.addition, ExerciseType.subtraction};

/// An honest upload: the questions the app asks, answered right.
SessionUpload honest(
  String id, {
  String player = 'p1',
  int minute = 0,
  Map<ExerciseType, Level>? levels,
}) {
  final session = PersistedSession(
    id: id,
    playerId: player,
    seed: 1000 + minute,
    enabledTypes: _types,
    exerciseCount: 8,
    totalScore: 0,
    levels: levels ?? {for (final t in _types) t: Level.floor},
    createdAt: DateTime.utc(2026, 11, 20, 9, minute),
    typeSequence: [
      for (var i = 0; i < 8; i++)
        i.isEven ? ExerciseType.addition : ExerciseType.subtraction,
    ],
  );
  final questions = replaySessionQuestions(session, [
    for (var i = 0; i < 8; i++) (isCorrect: true, elapsedMs: 0),
  ]);
  return SessionUpload(
    session: session,
    answers: [
      for (final (i, q) in questions.indexed)
        PersistedAnswer(
          id: '$id-$i',
          sessionId: id,
          exerciseType: describeExerciseForStorage(q).exerciseType,
          operationType: describeExerciseForStorage(q).operationType,
          operands: describeExerciseForStorage(q).operands,
          submittedValue: q.correctAnswer,
          isCorrect: true,
          elapsedMs: 1400 + 113 * i,
          createdAt: session.createdAt,
        ),
    ],
  );
}

void main() {
  late FakeGateway gateway;
  late Handler handler;

  setUp(() {
    gateway = FakeGateway()..users['token-p1'] = (id: 'p1', isAnonymous: true);
    handler = buildHandler(
      ServerConfig(
        supabaseUrl: Uri.parse('https://example.supabase.co'),
        supabaseSecretKey: 'sb_secret_test',
      ),
      routes: [
        SessionEndpoint(
          gateway,
          clock: () => DateTime.utc(2026, 11, 20, 10),
        ).route,
      ],
    );
  });

  Future<(int, Map<String, Object?>)> post(
    Object? body, {
    String? token = 'token-p1',
  }) async {
    final response = await handler(
      Request(
        'POST',
        Uri.parse('http://localhost/v1/sessions'),
        headers: {'authorization': ?(token == null ? null : 'Bearer $token')},
        body: body is String ? body : jsonEncode(body),
      ),
    );
    return (
      response.statusCode,
      (jsonDecode(await response.readAsString()) as Map)
          .cast<String, Object?>(),
    );
  }

  group('before any replay', () {
    test('no token or a bad one: 401, nothing touched', () async {
      expect((await post(honest('s').toJson(), token: null)).$1, 401);
      expect((await post(honest('s').toJson(), token: 'forged')).$1, 401);
      expect(gateway.calls, isEmpty);
    });

    test('malformed: 400 refused', () async {
      final (status, body) = await post('{"formatVersion": 1}');
      expect(status, 400);
      expect(body['reason'], 'badRequest');
      expect(gateway.calls, isEmpty);
    });

    test('another player’s session: refused', () async {
      final (status, body) = await post(honest('s', player: 'p2').toJson());
      expect(status, 409);
      expect(body['reason'], 'wrongPlayer');
      expect(gateway.calls, isEmpty);
    });

    test('Supabase down: 503; too large: 413', () async {
      gateway.down = true;
      expect((await post(honest('s').toJson())).$1, 503);
      gateway.down = false;
      expect((await post('x' * (maxUploadBytes + 1))).$1, 413);
    });
  });

  // Phase 5.1 commit 5: the invitation, enforced by the server.
  group('beta gate on the server', () {
    late Handler gated;

    setUp(() {
      gateway.users['token-linked'] = (id: 'linked', isAnonymous: false);
      gated = buildHandler(
        ServerConfig(
          supabaseUrl: Uri.parse('https://example.supabase.co'),
          supabaseSecretKey: 'sb_secret_test',
        ),
        routes: [
          SessionEndpoint(
            gateway,
            clock: () => DateTime.utc(2026, 11, 20, 10),
            requireBetaCode: true,
          ).route,
        ],
      );
    });

    Future<(int, Map<String, Object?>)> postGated(
      SessionUpload upload, {
      String token = 'token-p1',
    }) async {
      final response = await gated(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/sessions'),
          headers: {'authorization': 'Bearer $token'},
          body: jsonEncode(upload.toJson()),
        ),
      );
      return (
        response.statusCode,
        (jsonDecode(await response.readAsString()) as Map)
            .cast<String, Object?>(),
      );
    }

    test('an anonymous player without a code: 403, nothing stored', () async {
      final (status, body) = await postGated(honest('s1'));
      expect(status, 403);
      expect(body, {'error': 'beta_code_required'});
      // Not a refusal: no "status" for the app to record — it retries.
      expect(body.containsKey('status'), isFalse);
      expect(gateway.accepted, isEmpty);
      expect(gateway.rejected, isEmpty);
      expect(gateway.calls, ['upload_allowed']);
    });

    test('with a code: accepted', () async {
      gateway.withCode.add('p1');
      expect((await postGated(honest('s1'))).$1, 200);
    });

    test('a code redeemed later: the kept session goes through', () async {
      expect((await postGated(honest('s1'))).$1, 403);
      gateway.withCode.add('p1');
      expect((await postGated(honest('s1'))).$1, 200);
    });

    test(
      'a tester already in (accepted sessions, no code): accepted',
      () async {
        // Played before the gate existed: the ungated endpoint took it.
        expect((await post(honest('s1').toJson())).$1, 200);
        final next = honest(
          's2',
          minute: 5,
          levels: {
            for (final t in _types)
              t: Level.fromHundredths(
                (gateway.levels['p1']![t.name] as Map)['level'] as int,
              ),
          },
        );
        expect((await postGated(next)).$1, 200);
      },
    );

    test('a linked account is never asked', () async {
      final (status, _) = await postGated(
        honest('s1', player: 'linked'),
        token: 'token-linked',
      );
      expect(status, 200);
      expect(gateway.calls, isNot(contains('upload_allowed')));
    });

    test('Supabase down during the check: 503, retried later', () async {
      gateway.down = true;
      expect((await postGated(honest('s1'))).$1, 503);
    });
  });

  test(
    'honest sessions in a row: accepted, levels written, chain kept',
    () async {
      final (status, body) = await post(honest('s1').toJson());
      expect(status, 200);
      expect(body['status'], 'accepted');
      expect(body['syncedAt'], '2026-11-20T10:00:00+00:00');
      expect(
        gateway.levels['p1']!.keys,
        unorderedEquals(['addition', 'subtraction']),
      );

      // The next game, frozen at the levels the first produced.
      final next = honest(
        's2',
        minute: 5,
        levels: {
          for (final t in _types)
            t: Level.fromHundredths(
              (gateway.levels['p1']![t.name] as Map)['level'] as int,
            ),
        },
      );
      expect((await post(next.toJson())).$1, 200);
      expect(gateway.versions['p1'], 2);
    },
  );

  test('resent: the same answer, nothing written twice', () async {
    await post(honest('s1').toJson());
    final (status, body) = await post(honest('s1').toJson());
    expect(status, 200);
    expect(body['duplicate'], isTrue);
    expect(gateway.versions['p1'], 1);
  });

  test('a forged upload is rejected, recorded, and stays rejected', () async {
    final h = honest('forged');
    final forged = SessionUpload(
      session: h.session,
      answers: [
        for (final (i, a) in h.answers.indexed)
          i == 0
              ? PersistedAnswer(
                  id: a.id,
                  sessionId: a.sessionId,
                  exerciseType: a.exerciseType,
                  operationType: a.operationType,
                  // An easier question than the seed gives.
                  operands: const {'operandA': 1, 'operandB': 1},
                  submittedValue: 2,
                  isCorrect: true,
                  elapsedMs: a.elapsedMs,
                  createdAt: a.createdAt,
                )
              : a,
      ],
    );
    final (status, body) = await post(forged.toJson());
    expect(status, 409);
    expect(body['reason'], 'questionMismatch');
    expect(gateway.rejected['forged']!.reason, 'questionMismatch');
    expect(gateway.levels['p1'], isNull, reason: 'no level written');

    // Resent as an honest one: still the first verdict.
    final again = await post(honest('forged').toJson());
    expect(again.$2['reason'], 'questionMismatch');
  });

  test('levels that do not chain: refused with the server’s levels', () async {
    await post(honest('s1').toJson());
    // A second device, still at level 1.
    final (status, body) = await post(honest('s2', minute: 5).toJson());
    expect(status, 409);
    expect(body['reason'], 'levelsMismatch');
    expect(
      (body['levels'] as Map).keys,
      unorderedEquals(['addition', 'subtraction']),
    );
  });

  test(
    'a concurrent upload in between: validated again, then applied',
    () async {
      gateway.concurrentUploadFor.add('p1');
      final (status, _) = await post(honest('s1').toJson());
      expect(status, 200);
      expect(
        gateway.calls.where((c) => c == 'player_server_state'),
        hasLength(2),
      );
    },
  );
}
