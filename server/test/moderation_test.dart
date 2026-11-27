import 'dart:convert';
import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';
import 'session_endpoint_test.dart' show FakeGateway, honest;
import 'known_rules.dart';

/// Phase 6a commit 3 (plan v3.9; review M5): the cadence of a player's
/// sessions reaches the validation, and the owner's moderation is obeyed.
void main() {
  final config = ServerConfig(
    supabaseUrl: Uri.parse('https://example.supabase.co'),
    supabaseSecretKey: 'sb_secret_test',
  );

  group('sessions', () {
    late FakeGateway gateway;
    late Handler handler;

    setUp(() {
      gateway = FakeGateway()
        ..users['token-p1'] = (id: 'p1', isAnonymous: true);
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

    Future<(int, Map<String, Object?>)> post(Object body) async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/sessions'),
          headers: {'authorization': 'Bearer token-p1'},
          body: jsonEncode(body),
        ),
      );
      return (
        response.statusCode,
        (jsonDecode(await response.readAsString()) as Map)
            .cast<String, Object?>(),
      );
    }

    /// The levels the server holds for p1: what the next game chains from.
    Map<ExerciseType, Level> serverLevels() => {
      for (final type in const [
        ExerciseType.addition,
        ExerciseType.subtraction,
      ])
        type: Level.fromHundredths(
          ((gateway.levels['p1']?[type.name] as Map?)?['level'] as int?) ?? 0,
        ),
    };

    test('a session "created" while the previous one was still being '
        'played is accepted and flagged; the next honest one is not', () async {
      // s1 starts at 09:00:00 and takes 14.4 s.
      expect((await post(honest('s1').toJson())).$1, 200);
      expect(gateway.flags['s1'], isEmpty);
      expect(
        DateTime.parse(gateway.lastSessionEndsAt['p1']!),
        DateTime.utc(2026, 11, 20, 9, 0, 14, 364),
      );
      // s2 claims to have started at 09:00:00 as well: written, not lived.
      final (stacked, body) = await post(
        honest('s2', levels: serverLevels()).toJson(),
      );
      expect(stacked, 200, reason: '$body');
      expect(gateway.flags['s2'], ['overlapsPrevious']);
      // s3, a minute later, is an ordinary game again.
      final (next, nextBody) = await post(
        honest('s3', minute: 1, levels: serverLevels()).toJson(),
      );
      expect(next, 200, reason: '$nextBody');
      expect(gateway.flags['s3'], isEmpty);
      expect(
        DateTime.parse(gateway.lastSessionEndsAt['p1']!),
        DateTime.utc(2026, 11, 20, 9, 1, 14, 364),
      );
    });

    test('a suspended account: 403, nothing decided — neither accepted '
        'nor refused', () async {
      gateway.moderation['p1'] = 'banned';
      final (status, body) = await post(honest('s1').toJson());
      expect(status, 403);
      expect(body, {'error': 'account_suspended'});
      expect(gateway.accepted, isEmpty);
      expect(gateway.rejected, isEmpty);
      // Hidden is not suspended: the server still takes the games.
      gateway.moderation['p1'] = 'hidden';
      expect((await post(honest('s1').toJson())).$1, 200);
    });
  });

  group('duels', () {
    late FakeDuelGateway gateway;
    late Handler handler;
    var ids = 0;

    setUp(() {
      ids = 0;
      gateway = FakeDuelGateway()
        ..addUser('tok-a', 'ana', name: 'Ana')
        ..addUser('tok-b', 'bo', name: 'Bo')
        ..addUser('tok-c', 'cy', name: 'Cy');
      handler = buildHandler(
        config,
        routes: DuelEndpoint(
          gateway,
          seeds: Random(5),
          newId: () => 'duel-${++ids}',
        ).routes,
      );
    });

    Future<Map<String, Object?>> post(
      String path,
      Object body,
      String token,
    ) async {
      final response = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost$path'),
          headers: {'authorization': 'Bearer $token'},
          body: jsonEncode(withKnownRules(path, body)),
        ),
      );
      final json = (jsonDecode(await response.readAsString()) as Map)
          .cast<String, Object?>();
      return {...json, 'httpStatus': response.statusCode};
    }

    Future<void> practiceRun(String token) async {
      final practice = await post('/v1/duels', {'mode': 'basics'}, token);
      final config = DuelConfig.fromJson(practice['config']);
      final ok = await post('/v1/duels/run', {
        'duelId': practice['duelId'],
        'run': QuizRun([
          for (final (i, q) in config.questions().indexed)
            DuelAnswer(value: q.correctAnswer, elapsedMs: 3000 + 211 * i),
        ]).toJson(),
      }, token);
      expect(ok['httpStatus'], 200, reason: '$ok');
    }

    test('a hidden player leaves the pool, both ways: their run is not '
        'served, and they are matched with practice only', () async {
      await practiceRun('tok-a');
      await practiceRun('tok-b');
      gateway.moderation['ana'] = 'hidden';
      // Cy would have met Ana or Bo: only Bo is left.
      final cy = await post('/v1/duels', {'mode': 'basics'}, 'tok-c');
      expect((cy['opponent'] as Map)['name'], 'Bo');
      // Ana still plays — against a simulated opponent, never Bo's run.
      final ana = await post('/v1/duels', {'mode': 'basics'}, 'tok-a');
      expect((ana['httpStatus'], ana['kind']), (200, 'practice'));
      // No challenge from or to a hidden player, friends or not.
      gateway
        ..befriend('ana', 'bo')
        ..befriend('ana', 'cy');
      for (final (token, target) in [('tok-a', 'bo'), ('tok-b', 'ana')]) {
        final refused = await post('/v1/duels', {
          'mode': 'advanced',
          'challenge': target,
        }, token);
        expect((refused['httpStatus'], refused['reason']), (409, 'notAllowed'));
      }
    });

    test('a suspended player gets no new duel', () async {
      gateway.moderation['ana'] = 'banned';
      final refused = await post('/v1/duels', {'mode': 'basics'}, 'tok-a');
      expect(
        (refused['httpStatus'], refused['error']),
        (403, 'account_suspended'),
      );
      expect(gateway.duels, isEmpty);
    });
  });
}
