import 'dart:convert';
import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';
import 'known_rules.dart';

/// Phase 6a commit 1 (plan v3.9): the duel exploits of the review of 26 Nov
/// (`doc/review-2026-11-26.md`, B5, M1, M2, M3), each replayed against the
/// endpoints. Each must end in a loss or a refusal — never in a void duel
/// for the second player, never in a second go at the same questions.
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

  /// The first [answered] answers of [offer]: [right] of them right, each
  /// in [ms] plus 137 ms per question before it (never flat).
  QuizRun answers(
    Map<String, Object?> offer,
    int answered, {
    int? right,
    int ms = 4000,
  }) => QuizRun([
    for (final (i, q) in DuelConfig.fromJson(
      offer['config'],
    ).questions().take(answered).indexed)
      DuelAnswer(
        value: i < (right ?? answered) ? q.correctAnswer : q.correctAnswer + 1,
        elapsedMs: ms + 137 * i,
      ),
  ]);

  setUp(() {
    ids = 0;
    gateway = FakeDuelGateway()
      ..addUser('tok-a', 'ana', name: 'Ana')
      ..addUser('tok-b', 'bo', name: 'Bo')
      ..addUser('tok-c', 'cy', name: 'Cy');
    // Level 40 everywhere: a rating of 1500, questions with answers of two
    // digits and more (what the timing flags look at).
    for (final player in ['ana', 'bo', 'cy']) {
      gateway.levels[player] = {
        for (final type in ['addition', 'subtraction', 'multiplication'])
          type: 4000,
        'division': 4000,
      };
    }
    handler = buildHandler(
      ServerConfig.fromEnvironment(const {
        'SUPABASE_URL': 'https://x.supabase.co',
        'SUPABASE_SECRET_KEY': 'sb_secret_x',
        'ALLOWED_ORIGINS': 'https://app.example',
      }),
      routes: DuelEndpoint(
        gateway,
        seeds: Random(3),
        newId: () => 'duel-${++ids}',
      ).routes,
    );
  });

  /// A practice run of Ana in Basics ([right] right answers), in the pool.
  Future<void> anaRun({int right = 3}) async {
    final practice = await post('/v1/duels', {'mode': 'basics'}, 'tok-a');
    expect(practice['kind'], 'practice');
    final ok = await post('/v1/duels/run', {
      'duelId': practice['duelId'],
      'run': answers(practice, 8, right: right).toJson(),
    }, 'tok-a');
    expect(ok['httpStatus'], 200, reason: '$ok');
  }

  double rating(String player) =>
      (gateway.ratings[(player, 'basics')]!['rating'] as num).toDouble();

  group('B5 — the second player cannot escape a loss', () {
    test('a run with no answer: a rated loss, the duel not void, the same '
        'verdict for anything sent afterwards', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      expect(pooled['kind'], 'pool');
      final verdict = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': {'answers': <Object?>[]},
      }, 'tok-b');
      expect(verdict['httpStatus'], 200, reason: '$verdict');
      expect((verdict['status'], verdict['result']), ('accepted', 0));
      expect(verdict['rated'], isTrue);
      expect(verdict['flags'], contains('forfeited'));
      final duel = gateway.duels[pooled['duelId']]!;
      expect((duel['state'], duel['result'], duel['rated']), ('done', 0, true));
      expect(gateway.rejections[(pooled['duelId'], 'bo')], 'wrongShape');
      expect(rating('bo'), lessThan(1500), reason: 'the loss moved the rating');
      expect(gateway.ratings[('bo', 'basics')]!['ratedDuels'], 1);
      // A perfect run sent next: the loss stands.
      final again = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 8).toJson(),
      }, 'tok-b');
      expect((again['duplicate'], again['result']), (true, 0));
      // The forfeited run is never a run to race: Cy gets Ana's.
      final cy = await post('/v1/duels', {'mode': 'basics'}, 'tok-c');
      expect((cy['opponent'] as Map?)?['name'], 'Ana');
    });

    test('a run with an impossible time: a loss, recorded with nothing of '
        'it', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      final forged = QuizRun([
        for (final a in answers(pooled, 8).answers)
          DuelAnswer(value: a.value, elapsedMs: 99999),
      ]);
      final verdict = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': forged.toJson(),
      }, 'tok-b');
      expect((verdict['httpStatus'], verdict['result']), (200, 0));
      expect(gateway.rejections[(pooled['duelId'], 'bo')], 'badElapsed');
      final run = gateway.runs.firstWhere((r) => r['player'] == 'bo');
      expect(run['score'], {'points': 0, 'ms': 8 * 30000});
      expect(run['flags'], ['forfeited']);
    });

    test('a forfeit keeps the answers the server had received', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      final saved = await post('/v1/duels/progress', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 5).toJson(),
      }, 'tok-b');
      expect(saved['status'], 'saved');
      // The final run continues the progress but adds a forged time.
      final forged = QuizRun([
        ...answers(pooled, 5).answers,
        for (var i = 5; i < 8; i++) const DuelAnswer(value: 1, elapsedMs: -5),
      ]);
      final verdict = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': forged.toJson(),
      }, 'tok-b');
      expect((verdict['httpStatus'], verdict['result']), (200, 0));
      final run = gateway.runs.firstWhere((r) => r['player'] == 'bo');
      expect((run['score'] as Map)['points'], 5, reason: 'the progress');
    });

    test('an unreplayable progress, then silence: still a loss after 24 '
        'hours', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      final saved = await post('/v1/duels/progress', {
        'duelId': pooled['duelId'],
        'run': {
          'answers': [
            {'value': 1, 'ms': 99999},
          ],
        },
      }, 'tok-b');
      expect(saved['status'], 'saved', reason: 'it parses; not replayed yet');
      gateway.duels[pooled['duelId']]!['pastDeadline'] = true;
      await post('/v1/duels', {'mode': 'advanced'}, 'tok-c');
      final duel = gateway.duels[pooled['duelId']]!;
      expect((duel['state'], duel['result'], duel['rated']), ('done', 0, true));
      final run = gateway.runs.firstWhere((r) => r['player'] == 'bo');
      expect(run['flags'], containsAll(['abandoned', 'forfeited']));
      expect(rating('bo'), lessThan(1500));
    });

    test('a challenge opened and left: a loss even after its expiry; an '
        'expired challenge cannot be opened', () async {
      gateway.befriend('ana', 'bo');
      final challenge = await post('/v1/duels', {
        'mode': 'basics',
        'challenge': 'bo',
      }, 'tok-a');
      expect(challenge['kind'], 'challenge', reason: '$challenge');
      await post('/v1/duels/run', {
        'duelId': challenge['duelId'],
        'run': answers(challenge, 8, right: 4).toJson(),
      }, 'tok-a');
      final opened = await post('/v1/duels/open', {
        'duelId': challenge['duelId'],
      }, 'tok-b');
      expect(opened['httpStatus'], 200);
      // Bo leaves; the challenge expires; 24 hours pass.
      gateway.duels[challenge['duelId']]!
        ..['expired'] = true
        ..['expiresAt'] = '2000-01-01T00:00:00Z'
        ..['pastDeadline'] = true;
      await post('/v1/duels', {'mode': 'advanced'}, 'tok-c');
      final duel = gateway.duels[challenge['duelId']]!;
      expect((duel['state'], duel['result'], duel['rated']), ('done', 0, true));

      // Another challenge, never opened in time.
      final second = await post('/v1/duels', {
        'mode': 'advanced',
        'challenge': 'bo',
      }, 'tok-a');
      await post('/v1/duels/run', {
        'duelId': second['duelId'],
        'run': QuizRun(const []).completedWithTimeouts().toJson(),
      }, 'tok-a');
      gateway.duels[second['duelId']]!['expiresAt'] = '2000-01-01T00:00:00Z';
      final late = await post('/v1/duels/open', {
        'duelId': second['duelId'],
      }, 'tok-b');
      expect((late['httpStatus'], late['reason']), (409, 'expired'));
      // Nor played without being opened.
      final blind = await post('/v1/duels/run', {
        'duelId': second['duelId'],
        'run': QuizRun(const []).completedWithTimeouts().toJson(),
      }, 'tok-b');
      expect((blind['httpStatus'], blind['reason']), (409, 'notOpen'));
    });
  });

  group('M2 — no second go at the same questions', () {
    test('once the server holds progress, only its continuation is '
        'accepted', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      // Device 1: three answers, two of them wrong.
      final first = answers(pooled, 3, right: 1);
      expect(
        (await post('/v1/duels/progress', {
          'duelId': pooled['duelId'],
          'run': first.toJson(),
        }, 'tok-b'))['status'],
        'saved',
      );
      // Device 2 (the same duel is handed back): from the start, all right.
      final offer = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      expect(offer['duelId'], pooled['duelId']);
      final replay = await post('/v1/duels/progress', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 2).toJson(),
      }, 'tok-b');
      expect(
        (replay['httpStatus'], replay['reason']),
        (409, 'progressMismatch'),
      );
      final perfect = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 8).toJson(),
      }, 'tok-b');
      expect(
        (perfect['httpStatus'], perfect['reason']),
        (409, 'progressMismatch'),
      );
      final duel = gateway.duels[pooled['duelId']]!;
      expect(duel['state'], 'awaitingSecond', reason: 'still to be played');
      expect(gateway.runs.where((r) => r['player'] == 'bo'), isEmpty);
      expect(gateway.rejections, isEmpty);
      expect(duel['progress'], first.toJson(), reason: 'device 1 stands');
      // An older message of device 1 arriving late changes nothing either.
      final older = await post('/v1/duels/progress', {
        'duelId': pooled['duelId'],
        'run': QuizRun(first.answers.take(2).toList()).toJson(),
      }, 'tok-b');
      expect(older['reason'], 'progressMismatch');
      expect(
        gateway.duels[pooled['duelId']]!['progress'],
        first.toJson(),
        reason: 'what the server holds is never shortened',
      );
      // Device 1 finishes: its own three answers, then five more.
      final honest = QuizRun([
        ...first.answers,
        ...answers(pooled, 8).answers.skip(3),
      ]);
      final verdict = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': honest.toJson(),
      }, 'tok-b');
      expect(verdict['httpStatus'], 200, reason: '$verdict');
      expect((verdict['you'] as Map)['points'], 6);
    });
  });

  group('M3 — a rated duel is not aimed at a chosen player', () {
    test('a challenge only to a friend or a recent opponent', () async {
      final stranger = await post('/v1/duels', {
        'mode': 'basics',
        'challenge': 'cy',
      }, 'tok-a');
      expect((stranger['httpStatus'], stranger['reason']), (409, 'notAllowed'));
      gateway.befriend('cy', 'ana');
      final friend = await post('/v1/duels', {
        'mode': 'basics',
        'challenge': 'cy',
      }, 'tok-a');
      expect((friend['httpStatus'], friend['kind']), (200, 'challenge'));
    });

    test('rematchOf: a finished duel of the same mode only; then the '
        'opponent may be challenged', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      final early = await post('/v1/duels', {
        'mode': 'basics',
        'rematchOf': pooled['duelId'],
      }, 'tok-b');
      expect((early['httpStatus'], early['reason']), (409, 'notFinished'));
      await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 8).toJson(),
      }, 'tok-b');
      final other = await post('/v1/duels', {
        'mode': 'advanced',
        'rematchOf': pooled['duelId'],
      }, 'tok-b');
      expect((other['httpStatus'], other['reason']), (409, 'wrongMode'));
      // Ana has no other run: the rematch is a challenge, allowed because
      // they just played.
      final rematch = await post('/v1/duels', {
        'mode': 'basics',
        'rematchOf': pooled['duelId'],
      }, 'tok-b');
      expect((rematch['httpStatus'], rematch['kind']), (200, 'challenge'));
      // Cy never met Ana: a duel that is not theirs opens nothing.
      final foreign = await post('/v1/duels', {
        'mode': 'basics',
        'rematchOf': pooled['duelId'],
      }, 'tok-c');
      expect((foreign['httpStatus'], foreign['reason']), (409, 'notYourDuel'));
    });

    test('a rematch taken from the pool is a chosen duel: rated at most '
        'once in 24 hours per pair and mode', () async {
      await anaRun();
      await anaRun(right: 2);
      final first = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      final won = await post('/v1/duels/run', {
        'duelId': first['duelId'],
        'run': answers(first, 8).toJson(),
      }, 'tok-b');
      expect(won['rated'], isTrue);
      expect(gateway.duels[first['duelId']]!['chosen'], isFalse);
      final after = rating('bo');

      final rematch = await post('/v1/duels', {
        'mode': 'basics',
        'rematchOf': first['duelId'],
      }, 'tok-b');
      expect(rematch['kind'], 'pool', reason: 'Ana\'s other run');
      expect(gateway.duels[rematch['duelId']]!['chosen'], isTrue);
      // The pair's chosen duel of this mode was rated within 24 hours.
      gateway.pairRatedToday = (_) => true;
      final second = await post('/v1/duels/run', {
        'duelId': rematch['duelId'],
        'run': answers(rematch, 8).toJson(),
      }, 'tok-b');
      expect((second['httpStatus'], second['result']), (200, 1));
      expect(second['rated'], isFalse, reason: 'played, recorded, unrated');
      expect(rating('bo'), after);
      expect(gateway.ratings[('bo', 'basics')]!['ratedDuels'], 1);
    });
  });

  group('M1 — no faked time, nothing earned by a flagged run', () {
    test('a run claiming more time than has passed since the offer is a '
        'loss; unanswered questions claim nothing', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      // Ten seconds after the offer, eight answers "typed in 4 s each".
      gateway.elapsed = const Duration(seconds: 10);
      final verdict = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 8).toJson(),
      }, 'tok-b');
      expect((verdict['httpStatus'], verdict['result']), (200, 0));
      expect(gateway.rejections[(pooled['duelId'], 'bo')], 'notElapsed');
      expect(verdict['rated'], isTrue);
      expect(rating('bo'), lessThan(1500));

      // Cy, ten seconds in as well: two answers (8 s), then quits — the
      // six timeouts the app fills in were never waited for.
      final other = await post('/v1/duels', {'mode': 'basics'}, 'tok-c');
      final quit = await post('/v1/duels/run', {
        'duelId': other['duelId'],
        'run': answers(other, 2).completedWithTimeouts().toJson(),
      }, 'tok-c');
      expect(quit['httpStatus'], 200);
      expect(quit['flags'], isEmpty, reason: 'an ordinary run');
      expect(gateway.rejections.containsKey((other['duelId'], 'cy')), isFalse);
    });

    test('a challenger\'s own first run with faked time: refused, the '
        'challenge void', () async {
      gateway.befriend('ana', 'bo');
      final challenge = await post('/v1/duels', {
        'mode': 'basics',
        'challenge': 'bo',
      }, 'tok-a');
      gateway.elapsed = const Duration(seconds: 3);
      final refused = await post('/v1/duels/run', {
        'duelId': challenge['duelId'],
        'run': answers(challenge, 8).toJson(),
      }, 'tok-a');
      expect((refused['httpStatus'], refused['reason']), (409, 'notElapsed'));
      expect(gateway.duels[challenge['duelId']]!['state'], 'void');
    });

    test('a flagged winning run is unrated; a flagged losing run still '
        'loses', () async {
      await anaRun();
      final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      // Eight right answers in a tenth of a second each.
      final fast = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, 8, ms: 100).toJson(),
      }, 'tok-b');
      expect((fast['httpStatus'], fast['result']), (200, 1));
      expect(fast['flags'], contains('implausiblyFast'));
      expect(fast['rated'], isFalse);
      expect(gateway.ratings[('bo', 'basics')]!['ratedDuels'], 0);
      expect(rating('ana'), 1500, reason: 'Ana lost nothing to it');

      // Cy: two instant right answers, the rest wrong — flagged, and lost.
      final other = await post('/v1/duels', {'mode': 'basics'}, 'tok-c');
      final lost = await post('/v1/duels/run', {
        'duelId': other['duelId'],
        'run': answers(other, 8, right: 2, ms: 100).toJson(),
      }, 'tok-c');
      expect((lost['httpStatus'], lost['result']), (200, 0));
      expect(lost['flags'], contains('implausiblyFast'));
      expect(lost['rated'], isTrue, reason: 'a flag is no way out of a loss');
      expect(rating('cy'), lessThan(1500));
    });

    test('a duel against a flagged first run is unrated unless that run '
        'lost', () async {
      gateway.befriend('ana', 'bo');
      final challenge = await post('/v1/duels', {
        'mode': 'basics',
        'challenge': 'bo',
      }, 'tok-a');
      final mine = await post('/v1/duels/run', {
        'duelId': challenge['duelId'],
        'run': answers(challenge, 8, ms: 100).toJson(),
      }, 'tok-a');
      expect(mine['flags'], contains('implausiblyFast'));
      await post('/v1/duels/open', {'duelId': challenge['duelId']}, 'tok-b');
      final verdict = await post('/v1/duels/run', {
        'duelId': challenge['duelId'],
        'run': answers(challenge, 8, right: 5).toJson(),
      }, 'tok-b');
      expect((verdict['httpStatus'], verdict['result']), (200, 0));
      expect(verdict['rated'], isFalse, reason: 'Bo loses nothing to it');
    });
  });
}
