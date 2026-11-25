import 'duel_client.dart';
import 'duel_mode.dart';
import 'duel_rating.dart';

/// A player's rating in a mode, as the Online tab shows it.
typedef ModeRating = ({double rating, int ratedDuels});

/// A challenge waiting for the player ("Waiting for you").
final class WaitingChallenge {
  const WaitingChallenge({
    required this.duelId,
    required this.mode,
    required this.fromId,
    this.from,
    required this.expiresAt,
  });

  final String duelId;
  final DuelMode mode;
  final String fromId;

  /// `null`: no public name.
  final String? from;
  final DateTime expiresAt;
}

/// One of the player's latest duels ("Recent").
final class RecentDuel {
  const RecentDuel({
    required this.duelId,
    required this.mode,
    required this.kind,
    required this.at,
    required this.raced,
    this.opponentId,
    this.opponent,
    this.result,
    this.rated = false,
    this.waiting = false,
    this.voided = false,
  });

  final String duelId;
  final DuelMode mode;
  final DuelKind kind;
  final DateTime at;

  /// The player's run was the recorded one: [opponent] raced it.
  final bool raced;
  final String? opponentId;
  final String? opponent;

  /// From the player's side: 1, 0.5, 0; `null` while waiting or void.
  final double? result;
  final bool rated;

  /// A challenge the player sent, waiting for the friend.
  final bool waiting;

  /// A run was refused: the duel does not count.
  final bool voided;
}

/// The Online tab's data (`duel_overview()`): a guest gets only
/// [linked] false — online play needs a linked account (plan v3.7).
final class OnlineOverview {
  const OnlineOverview({
    required this.linked,
    this.ratings = const {},
    this.waiting = const [],
    this.recent = const [],
    this.friendRequests = 0,
  });

  static const guest = OnlineOverview(linked: false);

  final bool linked;
  final Map<DuelMode, ModeRating> ratings;
  final List<WaitingChallenge> waiting;
  final List<RecentDuel> recent;

  /// Friend requests waiting for an answer (commit 7).
  final int friendRequests;

  /// The tab's badge: something waits for the player.
  bool get needsAttention => waiting.isNotEmpty || friendRequests > 0;

  /// Whether the rating in [mode] is still provisional ("?").
  bool provisional(DuelMode mode) =>
      isProvisionalRating(ratings[mode]?.ratedDuels ?? 0);

  /// Strict on shape: a malformed answer throws [FormatException] (the
  /// screen offers a retry).
  factory OnlineOverview.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('overview');
    if (json['linked'] != true) return guest;
    final ratings = json['ratings'];
    final waiting = json['waiting'];
    final recent = json['recent'];
    if (ratings is! Map || waiting is! List || recent is! List) {
      throw const FormatException('overview: ratings, waiting or recent');
    }
    final requests = json['friendRequests'];
    return OnlineOverview(
      linked: true,
      ratings: {
        for (final mode in DuelMode.values)
          if (ratings[mode.name] case final Map r)
            mode: (
              rating: (r['rating'] as num).toDouble(),
              ratedDuels: r['ratedDuels'] as int,
            ),
      },
      waiting: [
        for (final w in waiting.cast<Map<Object?, Object?>>())
          WaitingChallenge(
            duelId: w['duelId'] as String,
            mode: DuelMode.parse(w['mode']),
            fromId: w['fromId'] as String,
            from: w['from'] as String?,
            expiresAt: DateTime.parse(w['expiresAt'] as String).toUtc(),
          ),
      ],
      recent: [
        for (final r in recent.cast<Map<Object?, Object?>>())
          RecentDuel(
            duelId: r['duelId'] as String,
            mode: DuelMode.parse(r['mode']),
            kind: DuelKind.parse(r['kind']),
            at: DateTime.parse(r['at'] as String).toUtc(),
            raced: r['raced'] == true,
            opponentId: r['opponentId'] as String?,
            opponent: r['opponent'] as String?,
            result: (r['result'] as num?)?.toDouble(),
            rated: r['rated'] == true,
            waiting: r['state'] == 'awaitingSecond',
            voided: r['state'] == 'void',
          ),
      ],
      friendRequests: requests is int ? requests : 0,
    );
  }
}

/// Reads the Online tab (Supabase). Throws on failure (offline…).
abstract interface class OnlineRepository {
  Future<OnlineOverview> overview();
}
