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

    test('a forged Get the count run from the second player: a loss, recorded '
        'once (Phase 6a: no void duel to escape through)', () async {
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
      expect(status, 200);
      expect((body['status'], body['result']), ('accepted', 0));
      expect(body['flags'], ['forfeited']);
      expect(gateway.duels['d2']!['state'], 'done');
      expect(gateway.rejections[('d2', 'player-a')], 'badDerivation');
      expect(gateway.runs, hasLength(1), reason: 'the forfeited run');
      // Resent, even "fixed": the same verdict.
      final (status2, body2) = await post('/v1/duels/run', {
        'duelId': 'd2',
        'run': CountRun([
          for (var i = 0; i < 3; i++) CountRoundRun(const []),
        ]).toJson(),
      });
      expect((status2, body2['duplicate'], body2['result']), (200, true, 0));
    });

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
      // A challenge is opened before it is played.
      final (blind, blindBody) = await post('/v1/duels/run', {
        'duelId': 'd3',
        'run': quizRun(6),
      });
      expect((blind, blindBody['reason']), (409, 'notOpen'));
      expect((await post('/v1/duels/open', {'duelId': 'd3'})).$1, 200);
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
        // A run that parses but does not replay is the second player's
        // loss, not a refusal (duel_integrity_test.dart).
        final (shape, shapeBody) = await post('/v1/duels/run', {
          'duelId': 'd4',
          'run': {'answers': []},
        });
        expect((shape, shapeBody['result']), (200, 0));
        expect(gateway.rejections[('d4', 'player-a')], 'wrongShape');
        expect((await post('/v1/duels/run', {'run': 1})).$1, 400);
      },
    );

    test('Supabase down: 503, the app retries', () async {
      gateway.down = true;
      expect((await post('/v1/duels/run', {'duelId': 'd'})).$1, 503);
    });
  });

  group('ratings (commit 3)', () {
    /// B races A's runs: a pool duel per run, A's rating row in place.
    Future<Map<String, Object?>> race(
      String id, {
      required int mine,
      required int theirs,
      String kind = 'pool',
      String first = 'player-b',
      String token = 'tok-a',
    }) async {
      insertDuel(
        id,
        config: basicsConfig,
        kind: kind == 'challenge' ? 'pool' : kind,
        first: kind == 'practice' ? null : first,
        lane: quizLane(theirs),
      );
      gateway.duels[id]!
        ..['kind'] = kind
        ..['openedAt'] = kind == 'challenge' ? '2026-11-26T12:00:00Z' : null;
      final (status, body) = await post('/v1/duels/run', {
        'duelId': id,
        'run': quizRun(mine),
      }, token: token);
      expect(status, 200, reason: '$body');
      return body;
    }

    void seedRating(String player, double rating, {int ratedDuels = 0}) {
      gateway.ratings[(player, 'basics')] = {
        'rating': rating,
        'deviation': 350.0,
        'volatility': 0.06,
        'ratedDuels': ratedDuels,
        'version': 0,
      };
    }

    test('a winning streak: the winner rises, the run owner falls, both '
        'counted; "?" until 10 rated duels', () async {
      seedRating('player-b', 1500);
      var previous = 1500.0;
      for (var i = 0; i < 10; i++) {
        final body = await race('w$i', mine: 7, theirs: 4);
        expect(body['rated'], isTrue);
        final rating = body['rating'] as Map;
        expect(rating['before'], i == 0 ? 1500 : previous);
        expect(rating['after'] as double, greaterThan(rating['before'] as num));
        expect(rating['provisional'], i < 9, reason: 'duel ${i + 1}');
        previous = rating['after'] as double;
      }
      final a = gateway.ratings[('player-a', 'basics')]!;
      final b = gateway.ratings[('player-b', 'basics')]!;
      expect(a['ratedDuels'], 10);
      expect(b['ratedDuels'], 10, reason: 'the run owner is rated too');
      expect(a['rating'] as double, greaterThan(1600));
      expect(b['rating'] as double, lessThan(1400));
      // Each grows surer (against an opponent as unsure: ~200 after ten).
      expect(a['deviation'] as double, lessThan(250));
      expect(gateway.duels['w9']!['firstRatingAfter'], b['rating']);
    });

    test(
      'practice moves nothing; the first rating starts from levels',
      () async {
        final body = await race('p1', mine: 8, theirs: 0, kind: 'practice');
        expect(body['rated'], isFalse);
        expect(gateway.ratings[('player-a', 'basics')], {
          'rating': 1500,
          'deviation': 350,
          'volatility': 0.06,
          'ratedDuels': 0,
          'version': 0,
        });
        expect((body['rating'] as Map)['provisional'], isTrue);
      },
    );

    test('challenges: rated once a day per pair and mode', () async {
      seedRating('player-b', 1500);
      var ratedToday = false;
      gateway.pairRatedToday = (_) => ratedToday;
      final first = await race('c1', mine: 6, theirs: 5, kind: 'challenge');
      expect(first['rated'], isTrue);
      ratedToday = true;
      final second = await race('c2', mine: 6, theirs: 5, kind: 'challenge');
      expect(second['rated'], isFalse, reason: 'played and recorded');
      expect(gateway.duels['c2']!['state'], 'done');
      expect(gateway.ratings[('player-a', 'basics')]!['ratedDuels'], 1);
      // A pool duel the same day is rated as usual.
      expect((await race('c3', mine: 6, theirs: 5))['rated'], isTrue);
    });

    test(
      'a rating moved meanwhile: read again, computed again, applied',
      () async {
        seedRating('player-b', 1500);
        gateway.concurrentDuelFor.add('player-b');
        final body = await race('s1', mine: 8, theirs: 2);
        expect(body['rated'], isTrue);
        expect(
          gateway.calls.where((c) => c == 'apply_duel_run').length,
          2,
          reason: 'stale once, then applied',
        );
        expect(gateway.ratings[('player-b', 'basics')]!['version'], 2);
      },
    );

    test('a draw between equals moves no rating', () {
      const even = Glicko2Rating(
        rating: 1500,
        deviation: 200,
        volatility: 0.06,
      );
      final drawn = rateDuel(first: even, second: even, secondScore: 0.5);
      expect(drawn.first.rating, closeTo(1500, 1e-9));
      expect(drawn.second.rating, closeTo(1500, 1e-9));
      expect(drawn.first.deviation, lessThan(200));
    });

    test('rateDuel: symmetric between equals; an upset moves more', () {
      const even = Glicko2Rating(
        rating: 1500,
        deviation: 100,
        volatility: 0.06,
      );
      final won = rateDuel(first: even, second: even, secondScore: 1);
      expect(won.second.rating - 1500, closeTo(1500 - won.first.rating, 1e-9));
      const strong = Glicko2Rating(
        rating: 1800,
        deviation: 100,
        volatility: 0.06,
      );
      final upset = rateDuel(first: strong, second: even, secondScore: 1);
      final expected = rateDuel(first: strong, second: even, secondScore: 0);
      expect(
        upset.second.rating - 1500,
        greaterThan(1500 - expected.second.rating),
      );
      // Never above the cap, even from a new player's deviation.
      const fresh = Glicko2Rating(
        rating: 1500,
        deviation: 350,
        volatility: 0.06,
      );
      final r = rateDuel(first: fresh, second: fresh, secondScore: 0.5);
      expect(r.first.deviation, lessThanOrEqualTo(duelMaxDeviation));
    });
  });
}
