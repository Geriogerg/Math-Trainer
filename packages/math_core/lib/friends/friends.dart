import '../duel/duel_mode.dart';
import '../duel/duel_run.dart';

/// A friend code: `MATH-` and 8 characters from the 32 easy ones (no I,
/// O, 0, 1) in two groups — 4 until Phase 6a (review m7: a million codes
/// were few enough to try) — as `normalize_friend_code` reads it in SQL:
/// "math 7k2p qx4m", "7K2PQX4M" and "MATH-7K2P-QX4M" are the same code.
/// `null` when [text] cannot be one.
String? normalizeFriendCode(String text) {
  var raw = text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  // The prefix only when the whole code is there: M, A, T and H are code
  // characters themselves.
  if (raw.length == 12 && raw.startsWith('MATH')) raw = raw.substring(4);
  return RegExp(r'^[A-HJ-NP-Z2-9]{8}$').hasMatch(raw)
      ? 'MATH-${raw.substring(0, 4)}-${raw.substring(4)}'
      : null;
}

/// The query parameter of an invite link: `<site>/?friend=MATH-7K2P-QX4M`.
const inviteLinkParameter = 'friend';

/// The invite link for [code] on the site at [origin] (the page's own).
Uri inviteLink(Uri origin, String code) => Uri(
  scheme: origin.scheme,
  host: origin.host,
  port: origin.hasPort ? origin.port : null,
  path: origin.path.isEmpty ? '/' : origin.path,
  queryParameters: {inviteLinkParameter: code},
);

/// A friend, with the head-to-head of every duel between the two.
final class Friend {
  const Friend({
    required this.id,
    this.name,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  final String id;

  /// `null`: no public name.
  final String? name;
  final int wins;
  final int losses;
  final int draws;
}

/// A request waiting for the player's answer.
final class FriendRequest {
  const FriendRequest({required this.fromId, this.name, required this.at});

  final String fromId;
  final String? name;
  final DateTime at;
}

/// One duel between the player and a friend (their history).
final class FriendDuel {
  const FriendDuel({
    required this.duelId,
    required this.mode,
    required this.at,
    required this.result,
    this.you,
    this.them,
  });

  final String duelId;
  final DuelMode mode;
  final DateTime at;

  /// From the player's side: 1, 0.5, 0.
  final double result;
  final DuelScore? you;
  final DuelScore? them;
}

/// What a request by code did (`friend_request`). Names are the server's.
enum FriendRequestOutcome {
  sent,

  /// They had asked the player already: friends now.
  friends,
  already,
  pending,
  unknown,
  self,

  /// 20 requests in the last 24 hours, failed ones included.
  tooMany,

  /// A reason this build does not know.
  other;

  static FriendRequestOutcome parse(Object? name) =>
      values.firstWhere((o) => o.name == name, orElse: () => other);
}

/// Friends, read and written straight on Supabase. Throws on failure.
abstract interface class FriendsRepository {
  /// The player's code (created on first use).
  Future<String> myCode();

  /// A new code for the player: the old one, and its invite links, find
  /// nobody any more (Phase 6a).
  Future<String> newCode();
  Future<FriendRequestOutcome> request(String code);
  Future<List<FriendRequest>> incoming();
  Future<void> respond(String fromId, {required bool accept});
  Future<void> remove(String friendId);
  Future<List<Friend>> friends();
  Future<List<FriendDuel>> history(String friendId);
}

List<Friend> friendsFromJson(Object? json) {
  if (json is! List) throw const FormatException('friends');
  return [
    for (final f in json.cast<Map<Object?, Object?>>())
      Friend(
        id: f['id'] as String,
        name: f['name'] as String?,
        wins: f['wins'] as int,
        losses: f['losses'] as int,
        draws: f['draws'] as int,
      ),
  ];
}

List<FriendRequest> friendRequestsFromJson(Object? json) {
  if (json is! List) throw const FormatException('friend requests');
  return [
    for (final r in json.cast<Map<Object?, Object?>>())
      FriendRequest(
        fromId: r['fromId'] as String,
        name: r['name'] as String?,
        at: DateTime.parse(r['at'] as String).toUtc(),
      ),
  ];
}

List<FriendDuel> friendHistoryFromJson(Object? json) {
  if (json is! List) throw const FormatException('friend history');
  return [
    for (final d in json.cast<Map<Object?, Object?>>())
      () {
        final mode = DuelMode.parse(d['mode']);
        DuelScore? score(Object? s) => s is Map
            ? DuelScore(
                mode: mode,
                points: s['points'] as int,
                totalMs: s['ms'] as int,
              )
            : null;
        return FriendDuel(
          duelId: d['duelId'] as String,
          mode: mode,
          at: DateTime.parse(d['at'] as String).toUtc(),
          result: (d['result'] as num).toDouble(),
          you: score(d['you']),
          them: score(d['them']),
        );
      }(),
  ];
}

/// An invite link's code, kept on the device until the player is linked
/// and the request is sent (a guest opening a link saves their progress
/// first). The app: `shared_preferences`.
abstract interface class PendingInviteStore {
  Future<String?> load();
  Future<void> save(String? code);
}
