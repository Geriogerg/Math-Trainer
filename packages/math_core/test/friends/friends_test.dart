import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/friends/friends.dart';
import 'package:test/test.dart';

void main() {
  test('codes read as the SQL reads them', () {
    expect(normalizeFriendCode('MATH-7K2P'), 'MATH-7K2P');
    expect(normalizeFriendCode(' math 7k2p '), 'MATH-7K2P');
    expect(normalizeFriendCode('7k2p'), 'MATH-7K2P');
    expect(normalizeFriendCode('MATH-MATH'), 'MATH-MATH');
    expect(normalizeFriendCode('MATH-7K2O'), isNull);
    expect(normalizeFriendCode('MATH-7K2'), isNull);
    expect(normalizeFriendCode(''), isNull);
  });

  test('invite links carry the code', () {
    final link = inviteLink(
      Uri.parse('https://math-trainer-kjc.pages.dev/?specimen#x'),
      'MATH-7K2P',
    );
    expect(
      link.toString(),
      'https://math-trainer-kjc.pages.dev/?friend=MATH-7K2P',
    );
    expect(link.queryParameters[inviteLinkParameter], 'MATH-7K2P');
  });

  test('outcomes, friends and history parse the server\'s shapes', () {
    expect(FriendRequestOutcome.parse('friends'), FriendRequestOutcome.friends);
    expect(FriendRequestOutcome.parse('new'), FriendRequestOutcome.other);
    final friends = friendsFromJson([
      {'id': 'l', 'name': 'Léa', 'wins': 3, 'losses': 2, 'draws': 0},
    ]);
    expect((friends.single.wins, friends.single.losses), (3, 2));
    final history = friendHistoryFromJson([
      {
        'duelId': 'd',
        'mode': 'count',
        'at': '2026-11-25T10:00:00+00:00',
        'result': 0.5,
        'you': {'points': 3, 'ms': 40000},
        'them': null,
      },
    ]);
    expect(history.single.mode, DuelMode.count);
    expect(history.single.you!.points, 3);
    expect(history.single.them, isNull);
    expect(() => friendsFromJson('x'), throwsFormatException);
  });
}
