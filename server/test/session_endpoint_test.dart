import 'dart:convert';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// Tokens map to users; database functions answer from a script.
class FakeGateway implements SupabaseGateway {
  final users = <String, AuthenticatedUser>{};
  final calls = <String>[];
  Object? Function(String name, Map<String, Object?> params)? onRpc;
  bool down = false;

  @override
  Future<AuthenticatedUser?> userForToken(String accessToken) async {
    if (down) throw const GatewayUnavailable('down');
    return users[accessToken];
  }

  @override
  Future<Object?> rpc(String name, Map<String, Object?> params) async {
    if (down) throw const GatewayUnavailable('down');
    calls.add(name);
    return onRpc!(name, params);
  }
}

SessionUpload uploadFor(String playerId) => SessionUpload(
  session: PersistedSession(
    id: '10000000-0000-0000-0000-000000000001',
    playerId: playerId,
    seed: 42,
    enabledTypes: const {ExerciseType.addition},
    exerciseCount: 1,
    totalScore: 0,
    levels: {ExerciseType.addition: Level.floor},
    createdAt: DateTime.utc(2026, 11, 20, 9),
    typeSequence: const [ExerciseType.addition],
  ),
  answers: [
    PersistedAnswer(
      id: 'a',
      sessionId: '10000000-0000-0000-0000-000000000001',
      exerciseType: 'arithmetic',
      operationType: 'addition',
      operands: const {'operandA': 1, 'operandB': 2},
      submittedValue: 3,
      isCorrect: true,
      elapsedMs: 900,
      createdAt: DateTime.utc(2026, 11, 20, 9),
    ),
  ],
);

void main() {
  late FakeGateway gateway;
  late Handler handler;

  setUp(() {
    gateway = FakeGateway()..users['token-p1'] = (id: 'p1', isAnonymous: true);
    final config = ServerConfig(
      supabaseUrl: Uri.parse('https://example.supabase.co'),
      supabaseSecretKey: 'sb_secret_test',
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

  Future<(int, Map<String, Object?>)> post({
    String? token = 'token-p1',
    Object? body,
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

  test('no token or a bad one: 401, nothing stored', () async {
    expect((await post(token: null, body: uploadFor('p1').toJson())).$1, 401);
    expect(
      (await post(token: 'forged', body: uploadFor('p1').toJson())).$1,
      401,
    );
    expect(gateway.calls, isEmpty);
  });

  test('malformed: 400 refused, nothing stored', () async {
    final (status, body) = await post(body: '{"formatVersion": 1}');
    expect(status, 400);
    expect(body['status'], 'refused');
    expect(body['reason'], 'badRequest');
    expect(gateway.calls, isEmpty);
  });

  test('another player\'s session: refused, nothing stored', () async {
    final (status, body) = await post(body: uploadFor('p2').toJson());
    expect(status, 409);
    expect(body['reason'], 'wrongPlayer');
    expect(gateway.calls, isEmpty);
  });

  test(
    'stored once, then a duplicate: both accepted with the stored time',
    () async {
      var stored = false;
      gateway.onRpc = (name, params) {
        expect(name, 'record_session_upload');
        expect(params['p_player_id'], 'p1');
        expect((params['p_payload'] as Map)['formatVersion'], 1);
        final outcome = stored ? 'duplicate' : 'inserted';
        stored = true;
        return [
          {'outcome': outcome, 'received_at': '2026-11-20T10:00:00+00:00'},
        ];
      };
      final first = await post(body: uploadFor('p1').toJson());
      expect(first.$1, 200);
      expect(first.$2, {
        'status': 'accepted',
        'syncedAt': '2026-11-20T10:00:00+00:00',
        'duplicate': false,
      });
      final again = await post(body: uploadFor('p1').toJson());
      expect(again.$2['duplicate'], isTrue);
    },
  );

  test('an id taken by another player: refused for good', () async {
    gateway.onRpc = (_, _) => [
      {'outcome': 'conflict', 'received_at': '2026-11-20T10:00:00+00:00'},
    ];
    final (status, body) = await post(body: uploadFor('p1').toJson());
    expect(status, 409);
    expect(body['reason'], 'idConflict');
  });

  test('Supabase down: 503, the app retries', () async {
    gateway.down = true;
    expect((await post(body: uploadFor('p1').toJson())).$1, 503);
  });

  test('too large: 413', () async {
    final (status, _) = await post(body: 'x' * (maxUploadBytes + 1));
    expect(status, 413);
  });
}
