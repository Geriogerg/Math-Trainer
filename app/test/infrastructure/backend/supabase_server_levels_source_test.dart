import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_trainer/infrastructure/backend/supabase_server_levels_source.dart';

import 'supabase_test_client.dart';

void main() {
  Future<SupabaseServerLevelsSource> sourceAnswering(
    Object? body, {
    int status = 200,
    List<String>? calls,
  }) async {
    final supabase = SupabaseTestClient(
      restHandler: (request) async {
        calls?.add('${request.method} ${request.url.path}');
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    addTearDown(supabase.client.dispose);
    await supabase.signIn();
    return SupabaseServerLevelsSource(supabase.client);
  }

  test('calls my_server_levels and parses the Postgres timestamps', () async {
    final calls = <String>[];
    final source = await sourceAnswering({
      'addition': {
        'level': 1850,
        'sessionsPlayed': 7,
        // What jsonb_build_object makes of a timestamptz.
        'updatedAt': '2026-11-21T10:00:00.123456+00:00',
      },
    }, calls: calls);

    final levels = await source.fetch();

    expect(calls, ['POST /rest/v1/rpc/my_server_levels']);
    expect(levels[ExerciseType.addition]!.level, Level.fromHundredths(1850));
    expect(levels[ExerciseType.addition]!.sessionsPlayed, 7);
    expect(levels[ExerciseType.addition]!.updatedAt.isUtc, isTrue);
  });

  test('no levels on the server: an empty cache', () async {
    final source = await sourceAnswering(<String, Object?>{});
    expect(await source.fetch(), isEmpty);
  });

  test('an error or a malformed answer throws (local levels kept)', () async {
    final refused = await sourceAnswering({
      'message': 'permission denied',
    }, status: 401);
    await expectLater(refused.fetch(), throwsA(isA<Exception>()));

    final malformed = await sourceAnswering({
      'addition': {'level': 'high'},
    });
    await expectLater(malformed.fetch(), throwsA(isA<FormatException>()));
  });
}
