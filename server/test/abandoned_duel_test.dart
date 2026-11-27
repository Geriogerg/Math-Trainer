import 'dart:convert';
import 'dart:math';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_duel_gateway.dart';

/// Phase 7 close-out commit 1 (plan v3.8): a duel started but not submitted
/// within 24 hours is a loss, from the answers the server received; the
/// sweep runs on any duel request.
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
        body: jsonEncode(body),
      ),
    );
    final json = (jsonDecode(await response.readAsString()) as Map)
        .cast<String, Object?>();
    return {...json, 'httpStatus': response.statusCode};
  }

  /// The first [answered] answers of [offer], all right, about 4 s each —
  /// the same answer at the same time however many follow (a later progress
  /// continues an earlier one).
  QuizRun answers(Map<String, Object?> offer, int answered) => QuizRun([
    for (final (i, q) in DuelConfig.fromJson(
      offer['config'],
    ).questions().take(answered).indexed)
      DuelAnswer(value: q.correctAnswer, elapsedMs: 4000 + i * 7),
  ]);

  setUp(() {
    gateway = FakeDuelGateway()
      ..addUser('tok-a', 'ana', name: 'Ana')
      ..addUser('tok-b', 'bo', name: 'Bo')
      ..addUser('tok-c', 'cy', name: 'Cy')
      ..befriend('ana', 'bo');
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

  /// Ana's practice run in Basics (3 right), in the pool.
  Future<void> anaRun() async {
    final practice = await post('/v1/duels', {'mode': 'basics'}, 'tok-a');
    final ok = await post('/v1/duels/run', {
      'duelId': practice['duelId'],
      'run': answers(practice, 3).completedWithTimeouts().toJson(),
    }, 'tok-a');
    expect(ok['httpStatus'], 200);
  }

  test('a pool duel left after 3 answers: a loss from those answers, '
      'rated, never in the pool', () async {
    await anaRun();
    final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
    expect(pooled['kind'], 'pool');
    // Bo answers 5 right, the app sending each step… then closes the tab.
    for (var n = 1; n <= 5; n++) {
      final saved = await post('/v1/duels/progress', {
        'duelId': pooled['duelId'],
        'run': answers(pooled, n).toJson(),
      }, 'tok-b');
      expect(saved['status'], 'saved');
    }
    // 24 hours later, anyone's duel request records it.
    gateway.duels[pooled['duelId']]!['pastDeadline'] = true;
    await post('/v1/duels', {'mode': 'advanced'}, 'tok-c');
    final duel = gateway.duels[pooled['duelId']]!;
    expect(duel['state'], 'done');
    expect(duel['result'], 0, reason: 'a loss, even with 5 right against 3');
    expect(duel['rated'], isTrue);
    final run = gateway.runs.firstWhere((r) => r['player'] == 'bo');
    expect((run['score'] as Map)['points'], 5, reason: 'the answers received');
    expect(run['flags'], contains('abandoned'));
    expect(gateway.ratings[('bo', 'basics')]!['ratedDuels'], 1);
    // Bo's late run gets the recorded verdict.
    final late = await post('/v1/duels/run', {
      'duelId': pooled['duelId'],
      'run': answers(pooled, 8).toJson(),
    }, 'tok-b');
    expect((late['duplicate'], late['result']), (true, 0));
    // Never served: Cy, who never played these questions, gets Ana's run.
    final cy = await post('/v1/duels', {'mode': 'basics'}, 'tok-c');
    expect((cy['opponent'] as Map?)?['name'], 'Ana');
  });

  test('no progress at all: a loss with every question unanswered', () async {
    await anaRun();
    final pooled = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
    gateway.duels[pooled['duelId']]!['pastDeadline'] = true;
    await post('/v1/duels', {'mode': 'count'}, 'tok-a');
    final run = gateway.runs.firstWhere((r) => r['player'] == 'bo');
    expect(run['score'], {'points': 0, 'ms': 8 * 30000});
    expect(gateway.duels[pooled['duelId']]!['result'], 0);
  });

  test('a malformed progress counts as none; practice stays unrated', () async {
    final practice = await post('/v1/duels', {'mode': 'count'}, 'tok-b');
    await post('/v1/duels/progress', {
      'duelId': practice['duelId'],
      'run': {'rounds': 'nonsense'},
    }, 'tok-b');
    gateway.duels[practice['duelId']]!['pastDeadline'] = true;
    await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
    final duel = gateway.duels[practice['duelId']]!;
    expect((duel['state'], duel['result'], duel['rated']), ('done', 0, false));
  });

  test('a challenge its challenger never played is void; progress only on '
      'one\'s own open duel', () async {
    final challenge = await post('/v1/duels', {
      'mode': 'advanced',
      'challenge': 'bo',
    }, 'tok-a');
    final refused = await post('/v1/duels/progress', {
      'duelId': challenge['duelId'],
      'run': {'answers': []},
    }, 'tok-b');
    expect((refused['httpStatus'], refused['reason']), (409, 'notOpen'));
    gateway.duels[challenge['duelId']]!['pastDeadline'] = true;
    await post('/v1/duels', {'mode': 'basics'}, 'tok-c');
    expect(gateway.duels[challenge['duelId']]!['state'], 'void');
  });

  // Plan v4.0 (Phase 6a outcome): the free server sleeps; when it starts it
  // records every duel left meanwhile, batch after batch, before anyone asks.
  test('a server start records every duel left while it slept', () async {
    final left = <String>[];
    for (var i = 0; i < 7; i++) {
      final practice = await post('/v1/duels', {'mode': 'basics'}, 'tok-b');
      left.add(practice['duelId'] as String);
      // Its hour to be handed back is over: the next request makes another.
      gateway.duels[practice['duelId']]!['stale'] = true;
    }
    for (final id in left) {
      gateway.duels[id]!['pastDeadline'] = true;
    }
    gateway.calls.clear();
    DuelEndpoint? endpoint;
    buildServerHandler(
      ServerConfig.fromEnvironment(const {
        'SUPABASE_URL': 'https://x.supabase.co',
        'SUPABASE_SECRET_KEY': 'sb_secret_x',
        'ALLOWED_ORIGINS': 'https://app.example',
      }),
      gateway: gateway,
      sweepEvery: const Duration(days: 1),
      duels: (e) => endpoint = e,
    );
    await endpoint!.sweepRunning;
    for (final id in left) {
      final duel = gateway.duels[id]!;
      expect((duel['state'], duel['result']), ('done', 0), reason: id);
    }
    // Batches of 3: 3, 3, 1 — the last one not full ends the catch-up.
    expect(gateway.calls.where((c) => c == 'duel_abandoned'), hasLength(3));
  });

  test('opening a challenge marks when its 24 hours start', () async {
    final challenge = await post('/v1/duels', {
      'mode': 'basics',
      'challenge': 'bo',
    }, 'tok-a');
    await post('/v1/duels/run', {
      'duelId': challenge['duelId'],
      'run': answers(challenge, 4).completedWithTimeouts().toJson(),
    }, 'tok-a');
    expect(gateway.duels[challenge['duelId']]!['openedAt'], isNull);
    await post('/v1/duels/open', {'duelId': challenge['duelId']}, 'tok-b');
    expect(gateway.duels[challenge['duelId']]!['openedAt'], isNotNull);
  });
}
