import 'dart:convert';
import 'dart:math';

import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';
import 'known_rules.dart';

/// Phase 7's exit test (plan v3.7), as far as the server decides it: two
/// linked players race each other's runs in all three modes and their
/// ratings move on the server only; a practice opponent appears when the
/// pool is empty; a forged or implausible run is never served. (Friends by
/// link and by code: `supabase/tests/99d_friends_test.sql` and the app's
/// `friends_screen_test.dart`; the live run is the owner's checklist.)
void main() {
  late FakeDuelGateway gateway;
  late Handler handler;
  var ids = 0;

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

  /// An honest run of [offer]: [correct] right, a human pace.
  DuelRun honest(Map<String, Object?> offer, {int correct = 6}) {
    final config = DuelConfig.fromJson(offer['config']);
    if (config.mode.isQuiz) {
      return QuizRun([
        for (final (i, q) in config.questions().indexed)
          DuelAnswer(
            value: i < correct ? q.correctAnswer : q.correctAnswer + 1,
            elapsedMs: 3000 + 411 * i,
          ),
      ]);
    }
    return CountRun([
      for (final (i, (puzzle, solution)) in config.rounds().indexed)
        CountRoundRun([
          // A stronger player (7+) solves all three rounds, others two.
          if (i < (correct >= 7 ? 3 : 2))
            CountImprovement(
              atMs: 12000 + 1000 * i,
              value: puzzle.target,
              steps: solution,
            ),
        ]),
    ]);
  }

  setUp(() {
    gateway = FakeDuelGateway()
      ..addUser('tok-a', 'ana', name: 'Ana')
      ..addUser('tok-b', 'bo', name: 'Bo');
    handler = buildHandler(
      ServerConfig.fromEnvironment(const {
        'SUPABASE_URL': 'https://x.supabase.co',
        'SUPABASE_SECRET_KEY': 'sb_secret_x',
        'ALLOWED_ORIGINS': 'https://app.example',
      }),
      routes: DuelEndpoint(
        gateway,
        seeds: Random(25),
        newId: () => 'duel-${++ids}',
      ).routes,
    );
  });

  test('two players, three modes: practice first, then each other\'s runs, '
      'both ratings moving', () async {
    for (final mode in ['basics', 'advanced', 'count']) {
      // The pool is empty: Ana gets a practice opponent; no rating moves.
      final practice = await post('/v1/duels', {'mode': mode}, 'tok-a');
      expect(practice['kind'], 'practice', reason: mode);
      final first = await post('/v1/duels/run', {
        'duelId': practice['duelId'],
        'run': honest(practice, correct: 5).toJson(),
      }, 'tok-a');
      expect(first['rated'], isFalse);

      // Bo races Ana's run: rated, both ratings move.
      final pooled = await post('/v1/duels', {'mode': mode}, 'tok-b');
      expect(pooled['kind'], 'pool', reason: mode);
      expect((pooled['opponent'] as Map)['name'], 'Ana');
      final anaBefore = gateway.ratings[('ana', mode)]!['rating'];
      final decided = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': honest(pooled, correct: 7).toJson(),
      }, 'tok-b');
      expect(decided['httpStatus'], 200, reason: '$decided');
      expect(decided['rated'], isTrue, reason: mode);
      final rating = decided['rating'] as Map;
      expect(rating['after'], isNot(rating['before']), reason: mode);
      expect(gateway.ratings[('ana', mode)]!['rating'], isNot(anaBefore));
      expect(gateway.ratings[('ana', mode)]!['ratedDuels'], 1);

      // And Ana races Bo's run in turn (another seed: Bo's practice).
      final boPractice = await post('/v1/duels', {'mode': mode}, 'tok-b');
      await post('/v1/duels/run', {
        'duelId': boPractice['duelId'],
        'run': honest(boPractice).toJson(),
      }, 'tok-b');
      final back = await post('/v1/duels', {'mode': mode}, 'tok-a');
      expect(back['kind'], 'pool');
      expect((back['opponent'] as Map)['name'], 'Bo');
    }
  });

  test('a forged run is a loss and never served; an implausible one is '
      'kept out of the pool', () async {
    // A forged Get the count run: a number that is not on the board.
    final practice = await post('/v1/duels', {'mode': 'count'}, 'tok-a');
    final forged = CountRun([
      CountRoundRun([
        CountImprovement(
          atMs: 1000,
          value: DuelConfig.fromJson(practice['config']).rounds()[0].$1.target,
          steps: [
            CountStep(
              1,
              CountOperator.add,
              DuelConfig.fromJson(practice['config']).rounds()[0].$1.target - 1,
              DuelConfig.fromJson(practice['config']).rounds()[0].$1.target,
            ),
          ],
        ),
      ]),
      CountRoundRun(const []),
      CountRoundRun(const []),
    ]);
    final refused = await post('/v1/duels/run', {
      'duelId': practice['duelId'],
      'run': forged.toJson(),
    }, 'tok-a');
    // Phase 6a: for a duel's second player a run that does not replay is a
    // loss — the forfeited run stored in its place is never one to race.
    expect((refused['httpStatus'], refused['result']), (200, 0));
    expect(gateway.rejections[(practice['duelId'], 'ana')], 'badDerivation');
    expect(gateway.runs.single['flags'], ['forfeited']);

    // An implausible Basics run: multi-digit answers in 120 ms.
    final basics = await post('/v1/duels', {'mode': 'basics'}, 'tok-a');
    final config = DuelConfig.fromJson(basics['config']);
    final fast = QuizRun([
      for (final q in config.questions())
        DuelAnswer(value: q.correctAnswer, elapsedMs: 120),
    ]);
    final flagged = await post('/v1/duels/run', {
      'duelId': basics['duelId'],
      'run': fast.toJson(),
    }, 'tok-a');
    // Every answer in 120 ms: flagged — implausibly fast when two answers
    // have several digits, and flat times always (which flag depends on
    // the questions the duel's rules draw: rules v9 from Phase 6b).
    expect(
      flagged['flags'],
      anyOf(contains('implausiblyFast'), contains('flatTimes')),
    );

    // Bo finds neither: practice in both modes.
    expect(
      (await post('/v1/duels', {'mode': 'count'}, 'tok-b'))['kind'],
      'practice',
    );
    expect(
      (await post('/v1/duels', {'mode': 'basics'}, 'tok-b'))['kind'],
      'practice',
    );
  });
}
