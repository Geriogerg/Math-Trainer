import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_trainer/infrastructure/backend/supabase_leaderboard_repository.dart';

import 'supabase_test_client.dart';

void main() {
  test('calls the board functions with the board key; parses both', () async {
    final calls = <String>[];
    final supabase = SupabaseTestClient(
      restHandler: (request) async {
        calls.add('${request.url.path} ${request.body}');
        final body = request.url.path.endsWith('leaderboard_top')
            ? [
                {'rank': 1, 'name': 'Ada', 'level': 4210, 'isMe': false},
                {'rank': 2, 'name': null, 'level': 3900, 'isMe': true},
              ]
            : {
                'eligible': true,
                'rank': 2,
                'total': 40,
                'topPercent': 5,
                'level': 3900,
                'neighbours': [],
              };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    addTearDown(supabase.client.dispose);
    await supabase.signIn();
    final repository = SupabaseLeaderboardRepository(supabase.client);

    final top = await repository.top(
      const LeaderboardBoard.of(ExerciseType.squareRoot),
    );
    final me = await repository.aroundMe(const LeaderboardBoard.main());

    expect(calls, [
      '/rest/v1/rpc/leaderboard_top {"p_board":"squareRoot"}',
      '/rest/v1/rpc/leaderboard_around_me {"p_board":"overall"}',
    ]);
    expect(top.first.name, 'Ada');
    expect(top.last.name, isNull);
    expect(top.last.isMe, isTrue);
    expect((me as Ranked).topPercent, 5);
    expect(me.level, Level.fromHundredths(3900));
  });
}
