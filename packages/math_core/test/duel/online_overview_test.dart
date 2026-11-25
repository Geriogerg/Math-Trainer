import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:test/test.dart';

void main() {
  test('the overview: ratings, waiting, recent, as the SQL answers', () {
    final o = OnlineOverview.fromJson({
      'linked': true,
      'ratings': {
        'basics': {'rating': 1542.4, 'ratedDuels': 12},
        'count': {'rating': 1610.0, 'ratedDuels': 3},
      },
      'waiting': [
        {
          'duelId': 'w1',
          'mode': 'basics',
          'fromId': 'lea',
          'from': 'Léa',
          'expiresAt': '2026-12-01T10:00:00+00:00',
        },
      ],
      'recent': [
        {
          'duelId': 'r1',
          'mode': 'basics',
          'kind': 'pool',
          'at': '2026-11-25T09:00:00+00:00',
          'state': 'done',
          'raced': true,
          'opponentId': 'tom',
          'opponent': 'Tom',
          'result': 1,
          'rated': true,
        },
        {
          'duelId': 'r2',
          'mode': 'advanced',
          'kind': 'practice',
          'at': '2026-11-25T08:00:00+00:00',
          'state': 'done',
          'raced': false,
          'opponentId': null,
          'opponent': null,
          'result': 0,
          'rated': false,
        },
      ],
      'friendRequests': 2,
    });
    expect(o.linked, isTrue);
    expect(o.ratings[DuelMode.basics]!.rating, 1542.4);
    expect(o.provisional(DuelMode.basics), isFalse);
    expect(o.provisional(DuelMode.count), isTrue);
    expect(o.provisional(DuelMode.advanced), isTrue, reason: 'no rating');
    expect(o.waiting.single.from, 'Léa');
    expect(o.recent.first.raced, isTrue);
    expect(o.recent.last.kind, DuelKind.practice);
    expect(o.recent.last.result, 0);
    expect(o.needsAttention, isTrue);
    expect(o.friendRequests, 2);
  });

  test('a guest: nothing but linked false', () {
    final o = OnlineOverview.fromJson({'linked': false});
    expect(o.linked, isFalse);
    expect(o.needsAttention, isFalse);
    expect(() => OnlineOverview.fromJson('x'), throwsFormatException);
  });

  test(
    'duel boards: after the main board, keyed by mode, ranked on rating',
    () {
      final all = LeaderboardBoard.all;
      expect(all.first, const LeaderboardBoard.main());
      expect(all.sublist(1, 4), [
        for (final m in DuelMode.values) LeaderboardBoard.duel(m),
      ]);
      expect(const LeaderboardBoard.duel(DuelMode.count).key, 'count');
      expect(const LeaderboardBoard.duel(DuelMode.basics).isDuel, isTrue);
      expect(
        const LeaderboardBoard.duel(DuelMode.basics),
        isNot(const LeaderboardBoard.main()),
      );
      final entries = leaderboardEntriesFromJson([
        {
          'rank': 1,
          'name': 'Léa',
          'rating': 1600,
          'isMe': false,
          'playerId': 'x',
        },
      ]);
      expect(entries.single.rating, 1600);
      expect(entries.single.level, isNull);
      final standing = standingFromJson({
        'eligible': false,
        'reason': 'provisional',
        'sessionsNeeded': 7,
      });
      expect((standing as NotRanked).reason, NotRankedReason.provisional);
      final ranked = standingFromJson({
        'eligible': true,
        'rank': 2,
        'total': 2,
        'topPercent': 100,
        'rating': 1500,
        'neighbours': [],
      });
      expect((ranked as Ranked).rating, 1500);
    },
  );
}
