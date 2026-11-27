@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/uuid.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import '../test/known_rules.dart';

/// The real server against the real SQL (Phase 6a commit 7, review M12):
/// `bin/server.dart` with its HTTP gateway, every migration applied to a
/// scratch Postgres, Supabase's two endpoints answered by
/// `tool/postgrest_shim.dart`. Plays a session upload and a duel in each
/// mode between two players, and the refusals that only the real boundary
/// produces. CI's integration job; locally:
///
///   INTEGRATION_DB_URL=postgresql://postgres@localhost:54329/mt_integration \
///   INTEGRATION_SERVER_URL=http://localhost:8091 dart test integration
void main() {
  final dbUrl = Platform.environment['INTEGRATION_DB_URL'];
  final serverUrl = Platform.environment['INTEGRATION_SERVER_URL'];
  if (dbUrl == null || serverUrl == null) {
    test('needs INTEGRATION_DB_URL and INTEGRATION_SERVER_URL', () {
      fail('not configured');
    });
    return;
  }
  final server = Uri.parse(serverUrl);
  late Connection db;

  final ana = generateUuidV4();
  final bo = generateUuidV4();
  final guest = generateUuidV4();

  /// A JWT-shaped token for [id] (the shim reads its `sub`).
  String token(String id) {
    String part(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final exp =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    return '${part({'alg': 'none'})}.${part({'sub': id, 'exp': exp})}.x';
  }

  Future<(int, Map<String, Object?>)> post(
    String path,
    Object body,
    String? who,
  ) async {
    final response = await http.post(
      server.resolve(path),
      headers: {
        'authorization': ?(who == null ? null : 'Bearer ${token(who)}'),
        'content-type': 'application/json',
      },
      body: jsonEncode(withKnownRules(path, body)),
    );
    return (
      response.statusCode,
      (jsonDecode(response.body) as Map).cast<String, Object?>(),
    );
  }

  Future<List<List<Object?>>> sql(
    String query, [
    Map<String, Object?> params = const {},
  ]) async => [
    for (final row in await db.execute(Sql.named(query), parameters: params))
      row.toList(),
  ];

  setUpAll(() async {
    final uri = Uri.parse(dbUrl);
    final user = uri.userInfo.split(':');
    db = await Connection.open(
      Endpoint(
        host: uri.host,
        port: uri.hasPort ? uri.port : 5432,
        database: uri.pathSegments.first,
        username: user.first,
        password: user.length > 1 ? user[1] : null,
      ),
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    for (final (id, anonymous) in [(ana, false), (bo, false), (guest, true)]) {
      await sql(
        'insert into auth.users (id, is_anonymous) values (cast(@id as uuid), @anonymous)',
        {'id': id, 'anonymous': anonymous},
      );
    }
  });

  tearDownAll(() => db.close());

  test('GET /health lists the current rules', () async {
    final health = jsonDecode((await http.get(server.resolve('/health'))).body);
    expect(health['rules'], contains(RulesVersion.current.number));
  });

  /// An honest 8-question game of [player], answered right and fluently.
  SessionUpload game(String id, String player) {
    const types = {ExerciseType.addition, ExerciseType.subtraction};
    final session = PersistedSession(
      id: id,
      playerId: player,
      seed: 20261126,
      enabledTypes: types,
      exerciseCount: 8,
      totalScore: 0,
      levels: {for (final t in types) t: Level.zero},
      createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 2)),
      typeSequence: [
        for (var i = 0; i < 8; i++)
          i.isEven ? ExerciseType.addition : ExerciseType.subtraction,
      ],
      rulesVersion: RulesVersion.current,
    );
    final questions = replaySessionQuestions(session, 8);
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

  test('a session upload: replayed, stored, levels and counts moved', () async {
    final id = generateUuidV4();
    final upload = game(id, ana);
    final (status, body) = await post('/v1/sessions', upload.toJson(), ana);
    expect(status, 200, reason: '$body');
    expect(body['status'], 'accepted');
    final stored = await sql(
      'select completed, rules_version from public.uploaded_sessions where id = cast(@id as uuid)',
      {'id': id},
    );
    expect(stored.single, [true, RulesVersion.current.number]);
    final player = await sql(
      'select completed_games, last_session_ends_at is not null from public.server_players where player_id = cast(@id as uuid)',
      {'id': ana},
    );
    expect(player.single, [1, true]);
    final levels = await sql(
      'select count(*)::int from public.server_levels where player_id = cast(@id as uuid) and level > 0',
      {'id': ana},
    );
    expect(levels.single.single, 2, reason: 'all right, fluent: both moved');
    // The same upload again: the same answer.
    final (again, againBody) = await post('/v1/sessions', upload.toJson(), ana);
    expect((again, againBody['duplicate']), (200, true));
  });

  test(
    'a session id that is not a UUID: refused for good (400), not 503',
    () async {
      // Parsed by the server, refused by the database's uuid column (PostgREST
      // 400): a final refusal, never "try again later" (review m2).
      final (status, body) = await post(
        '/v1/sessions',
        game('not-a-uuid', bo).toJson(),
        bo,
      );
      expect((status, body['reason']), (400, 'badRequest'), reason: '$body');
    },
  );

  // Phase 6c commit 5: an error report through the real function and
  // grants, masked, without an account.
  test('an error report: stored, masked, no account needed', () async {
    final response = await http.post(
      server.resolve('/v1/errors'),
      headers: {'content-type': 'text/plain;charset=UTF-8'},
      body: jsonEncode({
        'kind': 'loader',
        'message': 'engine did not start for ana@example.org',
        'appVersion': 'integration',
      }),
    );
    expect(response.statusCode, 202, reason: response.body);
    final rows = await sql(
      "select kind, message, app_version from public.client_errors "
      "where app_version = 'integration'",
    );
    expect(rows.single, [
      'loader',
      'engine did not start for <email>',
      'integration',
    ]);
  });

  test('guests, bad tokens', () async {
    final (guestStatus, guestBody) = await post('/v1/duels', {
      'mode': 'basics',
    }, guest);
    expect((guestStatus, guestBody['error']), (403, 'account_required'));
    final response = await http.post(
      server.resolve('/v1/duels'),
      headers: {'authorization': 'Bearer nonsense'},
      body: '{}',
    );
    expect(response.statusCode, 401);
  });

  for (final mode in DuelMode.values) {
    test('a ${mode.name} duel: practice, then the pool, rated for both', () async {
      DuelRun runFor(Map<String, Object?> offer) {
        final config = DuelConfig.fromJson(offer['config']);
        return mode.isQuiz
            ? QuizRun([
                for (final (i, q) in config.questions().indexed)
                  DuelAnswer(value: q.correctAnswer, elapsedMs: 400 + 37 * i),
              ])
            : CountRun([
                for (var r = 0; r < countDuelRounds; r++)
                  CountRoundRun(const <CountImprovement>[]),
              ]);
      }

      // Ana: nobody in the pool, a practice duel; her run joins the pool.
      final (s1, practice) = await post('/v1/duels', {'mode': mode.name}, ana);
      expect((s1, practice['kind']), (200, 'practice'), reason: '$practice');
      final (s2, mine) = await post('/v1/duels/run', {
        'duelId': practice['duelId'],
        'run': runFor(practice).toJson(),
      }, ana);
      expect((s2, mine['status']), (200, 'accepted'), reason: '$mine');
      expect(mine['rated'], isFalse, reason: 'practice');
      expect(
        (await sql(
          'select in_pool from public.duel_runs where player_id = cast(@id as uuid) and mode = @mode',
          {'id': ana, 'mode': mode.name},
        )).single.single,
        isTrue,
      );

      // Bo races Ana's run, sends his progress, then the run.
      final (s3, pooled) = await post('/v1/duels', {'mode': mode.name}, bo);
      expect((s3, pooled['kind']), (200, 'pool'), reason: '$pooled');
      expect((pooled['opponent'] as Map)['id'], ana);
      final run = runFor(pooled);
      final partial = switch (run) {
        final QuizRun q => QuizRun(q.answers.take(2).toList()),
        final CountRun c => CountRun(c.rounds.take(1).toList()),
      };
      final (s4, saved) = await post('/v1/duels/progress', {
        'duelId': pooled['duelId'],
        'run': partial.toJson(),
      }, bo);
      expect((s4, saved['status']), (200, 'saved'), reason: '$saved');
      final (s5, verdict) = await post('/v1/duels/run', {
        'duelId': pooled['duelId'],
        'run': run.toJson(),
      }, bo);
      expect((s5, verdict['status']), (200, 'accepted'), reason: '$verdict');
      expect(verdict['rated'], isTrue);
      expect(verdict['result'], anyOf(0, 0.5, 1));
      final ratings = await sql(
        'select count(*)::int from public.duel_ratings where mode = @mode and rated_duels = 1',
        {'mode': mode.name},
      );
      expect(ratings.single.single, 2, reason: 'both players moved');

      // A run that does not replay, sent for a new duel: Bo's loss.
      final (s6, next) = await post('/v1/duels', {'mode': mode.name}, bo);
      expect(s6, 200, reason: '$next');
      final (s7, forfeit) = await post('/v1/duels/run', {
        'duelId': next['duelId'],
        'run': mode.isQuiz ? {'answers': []} : {'rounds': []},
      }, bo);
      expect((s7, forfeit['result']), (200, 0), reason: '$forfeit');
      expect(forfeit['flags'], contains('forfeited'));
    });
  }
}
