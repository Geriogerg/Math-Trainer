import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  test('boards: overall first, then the seven, with the server keys', () {
    expect(
      [for (final b in LeaderboardBoard.all) b.key],
      ['overall', for (final t in ExerciseType.values) t.name],
    );
    expect(
      const LeaderboardBoard.of(ExerciseType.power),
      const LeaderboardBoard.of(ExerciseType.power),
    );
    expect(
      const LeaderboardBoard.overall(),
      isNot(const LeaderboardBoard.of(ExerciseType.power)),
    );
  });

  test('entries: a blank name reads as no name', () {
    final entries = leaderboardEntriesFromJson([
      {'rank': 1, 'name': 'Ada', 'level': 4210, 'isMe': false},
      {'rank': 1, 'name': '  ', 'level': 4210, 'isMe': true},
    ]);
    expect(entries.first.name, 'Ada');
    expect(entries.first.level, Level.fromHundredths(4210));
    expect(entries.last.name, isNull);
    expect(entries.last.isMe, isTrue);
  });

  test('a ranked standing', () {
    final s = standingFromJson({
      'eligible': true,
      'rank': 8,
      'total': 10,
      'topPercent': 80,
      'level': 2400,
      'neighbours': [
        {'rank': 7, 'name': 'B', 'level': 3200, 'isMe': false},
      ],
    });
    expect(s, isA<Ranked>());
    s as Ranked;
    expect((s.rank, s.total, s.topPercent), (8, 10, 80));
    expect(s.neighbours.single.name, 'B');
  });

  test('not ranked: the reason, and an unknown one stays readable', () {
    final s =
        standingFromJson({
              'eligible': false,
              'reason': 'notEnoughSessions',
              'sessionsNeeded': 2,
            })
            as NotRanked;
    expect(s.reason, NotRankedReason.notEnoughSessions);
    expect(s.sessionsNeeded, 2);
    expect(
      (standingFromJson({'eligible': false, 'reason': 'banned'}) as NotRanked)
          .reason,
      NotRankedReason.other,
    );
  });

  test('malformed answers throw FormatException', () {
    expect(() => leaderboardEntriesFromJson({}), throwsFormatException);
    expect(
      () => leaderboardEntriesFromJson([
        {'rank': '1', 'level': 100},
      ]),
      throwsFormatException,
    );
    expect(
      () => leaderboardEntriesFromJson([
        {'rank': 1, 'level': 0},
      ]),
      throwsFormatException,
    );
    expect(() => standingFromJson(null), throwsFormatException);
  });
}
