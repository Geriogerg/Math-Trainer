import 'dart:convert';
import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/practice_lane.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';
import 'known_rules.dart';

late FakeDuelGateway gateway;
late Handler handler;
var _ids = 0;

Future<(int, Map<String, Object?>)> post(
  String path,
  Object? body, {
  required String token,
}) async {
  final response = await handler(
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      headers: {'authorization': 'Bearer $token'},
      body: jsonEncode(withKnownRules(path, body)),
    ),
  );
  return (
    response.statusCode,
    (jsonDecode(await response.readAsString()) as Map).cast<String, Object?>(),
  );
}

/// Plays [offer] with [correct] right answers (values from the config).
Future<Map<String, Object?>> play(
  Map<String, Object?> offer,
  String token, {
  int correct = 6,
  int ms = 4000,
}) async {
  final config = DuelConfig.fromJson(offer['config']);
  final run = config.mode.isQuiz
      ? QuizRun([
          for (final (i, q) in config.questions().indexed)
            DuelAnswer(
              value: i < correct ? q.correctAnswer : q.correctAnswer + 1,
              elapsedMs: ms + 53 * i,
            ),
        ])
      : CountRun([
          for (final (puzzle, solution) in config.rounds())
            CountRoundRun([
              CountImprovement(
                atMs: 9000,
                value: puzzle.target,
                steps: solution,
              ),
            ]),
        ]);
  final (status, body) = await post('/v1/duels/run', {
    'duelId': offer['duelId'],
    'run': run.toJson(),
  }, token: token);
  expect(status, 200, reason: '$body');
  return body;
}

void main() {
  setUp(() {
    gateway = FakeDuelGateway()
      ..addUser('tok-a', 'a', name: 'Ana')
      ..addUser('tok-b', 'b', name: 'Bo')
      ..addUser('tok-c', 'c', name: 'Cy')
      ..addUser('tok-guest', 'guest', anonymous: true)
      ..befriend('a', 'b');
    // Ana: main level 40 → 1500 → T4.
    gateway.levels['a'] = {
      for (final t in ['addition', 'subtraction', 'multiplication', 'division'])
        t: 4000,
    };
    handler = buildHandler(
      ServerConfig.fromEnvironment(const {
        'SUPABASE_URL': 'https://x.supabase.co',
        'SUPABASE_SECRET_KEY': 'sb_secret_x',
        'ALLOWED_ORIGINS': 'https://app.example',
      }),
      routes: DuelEndpoint(
        gateway,
        seeds: Random(7),
        newId: () => 'duel-${++_ids}',
      ).routes,
    );
  });

  test('an empty pool: a practice opponent at the caller\'s rating', () async {
    final (status, offer) = await post('/v1/duels', {
      'mode': 'basics',
    }, token: 'tok-a');
    expect(status, 200, reason: '$offer');
    expect(offer['kind'], 'practice');
    expect(offer['opponent'], isNull);
    final config = DuelConfig.fromJson(offer['config']);
    expect(config.difficulty, 4, reason: 'rating 1500 → T4');
    // The simulated lane is the core's, from the config alone.
    expect(offer['lane'], practiceLane(config).toJson());
    // Asked again before playing: the same duel, never a new one.
    final (_, again) = await post('/v1/duels', {
      'mode': 'basics',
    }, token: 'tok-a');
    expect(again['duelId'], offer['duelId']);
    // Played: no rating change, the run joins the pool.
    final result = await play(offer, 'tok-a');
    expect(result['rated'], isFalse);
    expect(gateway.runs.single['player'], 'a');
  });

  test(
    'the pool: another player\'s run, never one\'s own; both rated',
    () async {
      final (_, practice) = await post('/v1/duels', {
        'mode': 'advanced',
      }, token: 'tok-a');
      await play(practice, 'tok-a', correct: 5);
      // Ana again: her own run is never served — practice.
      final (_, own) = await post('/v1/duels', {
        'mode': 'advanced',
      }, token: 'tok-a');
      expect(own['kind'], 'practice');
      // Bo races Ana's run.
      final (_, pooled) = await post('/v1/duels', {
        'mode': 'advanced',
      }, token: 'tok-b');
      expect(pooled['kind'], 'pool');
      expect((pooled['opponent'] as Map)['name'], 'Ana');
      expect(
        pooled['config'],
        practice['config'],
        reason: 'the same questions',
      );
      final lane = DuelLane.fromJson(
        pooled['lane'],
        DuelConfig.fromJson(pooled['config']).mode,
      );
      expect(lane.score.points, 5);
      final result = await play(pooled, 'tok-b', correct: 7);
      expect(result['result'], 1);
      expect(result['rated'], isTrue);
      expect(gateway.ratings[('a', 'advanced')]!['ratedDuels'], 1);
      expect(gateway.ratings[('b', 'advanced')]!['ratedDuels'], 1);
    },
  );

  test('a flagged run is never served', () async {
    final (_, practice) = await post('/v1/duels', {
      'mode': 'basics',
    }, token: 'tok-a');
    // Implausibly fast: multi-digit answers in 100 ms.
    final flagged = await play(practice, 'tok-a', correct: 8, ms: 100);
    expect(flagged['flags'], contains('implausiblyFast'));
    final (_, offer) = await post('/v1/duels', {
      'mode': 'basics',
    }, token: 'tok-b');
    expect(offer['kind'], 'practice', reason: 'kept out of the pool');
  });

  test('Get the count: practice, then the pool', () async {
    final (_, practice) = await post('/v1/duels', {
      'mode': 'count',
    }, token: 'tok-a');
    expect(
      DuelConfig.fromJson(practice['config']).difficulty,
      1,
      reason: 'a new player: 1300 → the middle band',
    );
    final mine = await play(practice, 'tok-a');
    expect((mine['you'] as Map)['points'], 0);
    final (_, pooled) = await post('/v1/duels', {
      'mode': 'count',
    }, token: 'tok-b');
    expect(pooled['kind'], 'pool');
    final result = await play(pooled, 'tok-b');
    // Both solved every round at 9 s: equal distance, equal time — a draw.
    expect(result['result'], 0.5);
  });

  test('rematch: another run of the same opponent, else a challenge', () async {
    final (_, p1) = await post('/v1/duels', {'mode': 'basics'}, token: 'tok-a');
    await play(p1, 'tok-a');
    final (_, pooled) = await post('/v1/duels', {
      'mode': 'basics',
    }, token: 'tok-b');
    await play(pooled, 'tok-b');
    // Ana has no other run: the rematch becomes a challenge to her.
    final (status, rematch) = await post('/v1/duels', {
      'mode': 'basics',
      'rematchOf': pooled['duelId'],
    }, token: 'tok-b');
    expect(status, 200, reason: '$rematch');
    expect(rematch['kind'], 'challenge');
    expect(rematch['lane'], isNull, reason: 'Bo plays first');
    expect((rematch['opponent'] as Map)['name'], 'Ana');
    // Ana plays another practice run; Bo's next rematch races it.
    final (_, p2) = await post('/v1/duels', {'mode': 'basics'}, token: 'tok-a');
    expect(p2['kind'], 'practice');
    await play(p2, 'tok-a');
    final (_, again) = await post('/v1/duels', {
      'mode': 'basics',
      'rematchOf': pooled['duelId'],
    }, token: 'tok-b');
    expect(again['kind'], 'pool');
    expect(again['config'], p2['config']);
    // After a practice duel, a rematch is a new search.
    final (_, fresh) = await post('/v1/duels', {
      'mode': 'basics',
      'rematchOf': p1['duelId'],
    }, token: 'tok-a');
    expect(fresh['kind'], isNot('challenge'));
  });

  test(
    'challenges: the challenger first, the friend opens and decides',
    () async {
      final (_, offer) = await post('/v1/duels', {
        'mode': 'advanced',
        'challenge': 'b',
      }, token: 'tok-a');
      expect(offer['kind'], 'challenge');
      final duelId = offer['duelId'];
      // Bo cannot open it before Ana played.
      final (early, earlyBody) = await post('/v1/duels/open', {
        'duelId': duelId,
      }, token: 'tok-b');
      expect((early, earlyBody['reason']), (409, 'notOpen'));
      final waiting = await play(offer, 'tok-a', correct: 4);
      expect(waiting['waiting'], isTrue);
      final (status, opened) = await post('/v1/duels/open', {
        'duelId': duelId,
      }, token: 'tok-b');
      expect(status, 200, reason: '$opened');
      expect((opened['opponent'] as Map)['name'], 'Ana');
      expect(opened['config'], offer['config']);
      expect(opened['lane'], isNotNull);
      final result = await play(opened, 'tok-b', correct: 5);
      expect(result['result'], 1);
      expect(result['rated'], isTrue);
      // Opened again once decided: not open.
      final (done, doneBody) = await post('/v1/duels/open', {
        'duelId': duelId,
      }, token: 'tok-b');
      expect((done, doneBody['reason']), (409, 'notOpen'));
      // Cy cannot open someone else's challenge.
      final (other, otherBody) = await post('/v1/duels/open', {
        'duelId': duelId,
      }, token: 'tok-c');
      expect((other, otherBody['reason']), (409, 'notYourDuel'));
    },
  );

  test('challenge refusals: oneself, a guest, one already open', () async {
    Future<String?> reason(String target) async =>
        (await post('/v1/duels', {
              'mode': 'basics',
              'challenge': target,
            }, token: 'tok-a')).$2['reason']
            as String?;
    expect(await reason('a'), 'self');
    expect(await reason('guest'), 'notLinked');
    expect(await reason('nobody'), 'notLinked');
    expect(await reason('b'), isNull);
    expect(await reason('b'), 'exists');
  });

  test('guests and unknown modes are refused', () async {
    expect(
      (await post('/v1/duels', {'mode': 'basics'}, token: 'tok-guest')).$1,
      403,
    );
    final (status, body) = await post('/v1/duels', {
      'mode': 'chain',
    }, token: 'tok-a');
    expect((status, body['reason']), (400, 'badRequest'));
  });
}
