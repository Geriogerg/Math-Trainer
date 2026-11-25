import 'dart:convert';

import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';

/// The pinned Basics duel (math_core's `duel_config_test.dart`).
final basicsConfig = DuelConfig(
  mode: DuelMode.basics,
  seed: 1,
  difficulty: 4,
  rulesVersion: RulesVersion.v8,
);
const basicsAnswers = [7897, 3330, 3949, 259, 147, 108, 7957, 17050];

final countConfig = DuelConfig(
  mode: DuelMode.count,
  seed: 987654321,
  difficulty: 2,
  rulesVersion: RulesVersion.v8,
);

/// [correct] right answers out of 8, in [ms] each (varied, never flat).
Map<String, Object?> quizRun(int correct, {int ms = 4000}) => QuizRun([
  for (final (i, v) in basicsAnswers.indexed)
    DuelAnswer(value: i < correct ? v : v + 1, elapsedMs: ms + 37 * i),
]).toJson();

/// A practice lane: [correct] right, 5 s each.
Map<String, Object?> quizLane(int correct) => QuizLane([
  for (var i = 0; i < 8; i++) (elapsedMs: 5000, correct: i < correct),
]).toJson();

late FakeDuelGateway gateway;
late Handler handler;

Future<(int, Map<String, Object?>)> post(
  String path,
  Object? body, {
  String? token = 'tok-a',
}) async {
  final response = await handler(
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'authorization': ?(token == null ? null : 'Bearer $token')},
      body: jsonEncode(body),
    ),
  );
  final text = await response.readAsString();
  return (
    response.statusCode,
    (jsonDecode(text) as Map).cast<String, Object?>(),
  );
}

void insertDuel(
  String id, {
  required DuelConfig config,
  String kind = 'practice',
  String? first,
  String second = 'player-a',
  Map<String, Object?>? lane,
}) {
  gateway.duels[id] = {
    'id': id,
    'mode': config.mode.name,
    'kind': kind,
    'config': config.toJson(),
    'firstPlayer': first,
    'secondPlayer': second,
    'firstLane': lane,
    'state': kind == 'challenge' ? 'awaitingFirst' : 'awaitingSecond',
    'rated': false,
  };
}

void main() {
  setUp(() {
    gateway = FakeDuelGateway()
      ..addUser('tok-a', 'player-a', name: 'Ana')
      ..addUser('tok-b', 'player-b', name: 'Bo')
      ..addUser('tok-guest', 'guest', anonymous: true);
    gateway.levels['player-a'] = {
      'addition': 4000,
      'subtraction': 4000,
      'multiplication': 4000,
      'division': 4000,
    };
    handler = buildHandler(
      ServerConfig.fromEnvironment(const {
        'SUPABASE_URL': 'https://x.supabase.co',
        'SUPABASE_SECRET_KEY': 'sb_secret_x',
        'ALLOWED_ORIGINS': 'https://app.example',
      }),
      routes: DuelEndpoint(gateway).routes,
    );
  });

  group('POST /v1/duels/run', () {
    test(
      'a practice duel: replayed, decided, the rating created, unrated',
      () async {
        insertDuel('d1', config: basicsConfig, lane: quizLane(6));
        final (status, body) = await post('/v1/duels/run', {
          'duelId': 'd1',
          'run': quizRun(7),
        });
        expect(status, 200, reason: '$body');
        expect(body['status'], 'accepted');
        expect(body['duplicate'], isFalse);
        expect(body['role'], 'second');
        expect(body['result'], 1);
        expect((body['you'] as Map)['points'], 7);
        expect(body['them'], {'points': 6, 'ms': 40000});
        expect(body['rated'], isFalse);
        // Main level 40 → 900 + 600.
        expect(gateway.ratings[('player-a', 'basics')]!['rating'], 1500);
        expect(gateway.duels['d1']!['state'], 'done');
        // The run is stored with its lane (no values typed) for the pool.
        final stored = gateway.runs.single;
        expect(jsonEncode(stored['lane']), isNot(contains('7897')));
      },
    );

    test('resent: the same answer, nothing applied twice', () async {
      insertDuel('d1', config: basicsConfig, lane: quizLane(8));
      final (_, first) = await post('/v1/duels/run', {
        'duelId': 'd1',
        'run': quizRun(7),
      });
      final (status, again) = await post('/v1/duels/run', {
        'duelId': 'd1',
        'run': quizRun(8),
      });
      expect(status, 200);
      expect(again['duplicate'], isTrue);
      expect(again['result'], first['result']);
      expect(again['result'], 0);
      expect(gateway.runs.length, 1);
    });

    test(
      'a forged Get the count run: refused, the duel void, recorded once',
      () async {
        insertDuel(
          'd2',
          config: countConfig,
          lane: CountLane([
            for (var i = 0; i < 3; i++)
              CountLaneRound(baseDistance: 50, improvements: const []),
          ]).toJson(),
        );
        final forged = CountRun([
          CountRoundRun([
            CountImprovement(
              atMs: 4000,
              value: 442,
              steps: const [CountStep(400, CountOperator.add, 42, 442)],
            ),
          ]),
          CountRoundRun(const []),
          CountRoundRun(const []),
        ]);
        final (status, body) = await post('/v1/duels/run', {
          'duelId': 'd2',
          'run': forged.toJson(),
        });
        expect(status, 409);
        expect(body, {'status': 'refused', 'reason': 'badDerivation'});
        expect(gateway.duels['d2']!['state'], 'void');
        expect(gateway.runs, isEmpty);
        // Resent, even "fixed": the same verdict.
        final (status2, body2) = await post('/v1/duels/run', {
          'duelId': 'd2',
          'run': CountRun([
            for (var i = 0; i < 3; i++) CountRoundRun(const []),
          ]).toJson(),
        });
        expect((status2, body2['reason']), (409, 'badDerivation'));
      },
    );

    test('a challenge: the challenger waits, the friend decides', () async {
      insertDuel(
        'd3',
        config: basicsConfig,
        kind: 'challenge',
        first: 'player-b',
        second: 'player-a',
      );
      // The friend cannot play before the challenger.
      final (early, earlyBody) = await post('/v1/duels/run', {
        'duelId': 'd3',
        'run': quizRun(8),
      });
      expect((early, earlyBody['reason']), (409, 'notOpen'));
      final (s1, b1) = await post('/v1/duels/run', {
        'duelId': 'd3',
        'run': quizRun(5),
      }, token: 'tok-b');
      expect(s1, 200, reason: '$b1');
      expect(b1['role'], 'first');
      expect(b1['waiting'], isTrue);
      expect(b1.containsKey('result'), isFalse);
      final (s2, b2) = await post('/v1/duels/run', {
        'duelId': 'd3',
        'run': quizRun(6),
      });
      expect(s2, 200);
      expect(b2['result'], 1);
      expect((b2['them'] as Map)['points'], 5);
      // The challenger, asking again, now learns the result.
      final (_, b3) = await post('/v1/duels/run', {
        'duelId': 'd3',
        'run': quizRun(5),
      }, token: 'tok-b');
      expect(b3['duplicate'], isTrue);
      expect(b3['result'], 0);
      expect(b3['waiting'], isFalse);
    });

    test(
      'refusals: no token, a guest, no duel, someone else\'s, malformed',
      () async {
        insertDuel('d4', config: basicsConfig, lane: quizLane(4));
        expect((await post('/v1/duels/run', {}, token: null)).$1, 401);
        expect((await post('/v1/duels/run', {}, token: 'nope')).$1, 401);
        final (guest, guestBody) = await post('/v1/duels/run', {
          'duelId': 'd4',
        }, token: 'tok-guest');
        expect((guest, guestBody['error']), (403, 'account_required'));
        final (none, noneBody) = await post('/v1/duels/run', {
          'duelId': 'nope',
          'run': quizRun(1),
        });
        expect((none, noneBody['reason']), (404, 'unknownDuel'));
        final (other, otherBody) = await post('/v1/duels/run', {
          'duelId': 'd4',
          'run': quizRun(1),
        }, token: 'tok-b');
        expect((other, otherBody['reason']), (409, 'notYourDuel'));
        final (bad, badBody) = await post('/v1/duels/run', {
          'duelId': 'd4',
          'run': {'rounds': []},
        });
        expect((bad, badBody['reason']), (400, 'badRequest'));
        final (shape, shapeBody) = await post('/v1/duels/run', {
          'duelId': 'd4',
          'run': {'answers': []},
        });
        expect((shape, shapeBody['reason']), (409, 'wrongShape'));
        expect((await post('/v1/duels/run', {'run': 1})).$1, 400);
      },
    );

    test('Supabase down: 503, the app retries', () async {
      gateway.down = true;
      expect((await post('/v1/duels/run', {'duelId': 'd'})).$1, 503);
    });
  });
}
