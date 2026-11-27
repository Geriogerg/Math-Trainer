import '../leveling/rules_version.dart';
import 'duel_config.dart';
import 'duel_mode.dart';
import 'duel_rating.dart';
import 'duel_run.dart';

/// What an app declares with every request for a duel (`find`, `open`;
/// plan v4.1, "deploy-window duels"): the game and duel rules versions it
/// can play. The server hands a duel only to an app that knows its own
/// current versions ([knowsCurrentDuelRules]) — an app opened before a
/// deploy that added a version is told to reload (`appOutdated`) instead
/// of getting a duel it cannot read, which it would lose 24 hours later.
Map<String, Object?> knownDuelRules() => {
  'rules': [for (final v in RulesVersion.replayed) v.number],
  'duelRules': [for (final v in DuelRulesVersion.replayed) v.number],
};

/// Whether a duel request's [body] declares the current game and duel
/// rules versions ([knownDuelRules]). An app that declares nothing (every
/// build before plan v4.1) does not.
bool knowsCurrentDuelRules(Map<String, Object?> body) {
  final rules = body['rules'];
  final duelRules = body['duelRules'];
  return rules is List &&
      rules.contains(RulesVersion.current.number) &&
      duelRules is List &&
      duelRules.contains(DuelRulesVersion.current.number);
}

/// How a duel came about (stored names: the server sends them).
enum DuelKind {
  /// A recorded run from the pool.
  pool,

  /// A simulated opponent: no rating change.
  practice,

  /// A challenge between two players (a friend, or a rematch's opponent).
  challenge;

  static DuelKind parse(Object? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    throw FormatException('unknown duel kind $name');
  }
}

/// The player raced, as the server shows them.
final class DuelOpponent {
  const DuelOpponent({
    required this.id,
    this.name,
    this.rating,
    this.ratedDuels = 0,
  });

  final String id;

  /// `null`: no public name (none chosen, or hidden after reports).
  final String? name;
  final double? rating;
  final int ratedDuels;

  bool get provisional => isProvisionalRating(ratedDuels);

  static DuelOpponent? fromJson(Object? json) {
    if (json == null) return null;
    if (json is! Map || json['id'] is! String) {
      throw const FormatException('opponent');
    }
    return DuelOpponent(
      id: json['id'] as String,
      name: json['name'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratedDuels: (json['ratedDuels'] as int?) ?? 0,
    );
  }
}

/// A duel to play (`POST /v1/duels`, `/v1/duels/open`): its content, the
/// opponent's lane (none for a challenge the player opens, who plays
/// first), the opponent (none for practice).
final class DuelOffer {
  const DuelOffer({
    required this.duelId,
    required this.kind,
    required this.config,
    this.lane,
    this.opponent,
  });

  final String duelId;
  final DuelKind kind;
  final DuelConfig config;
  final DuelLane? lane;
  final DuelOpponent? opponent;

  DuelMode get mode => config.mode;

  factory DuelOffer.fromJson(Object? json) {
    if (json is! Map || json['duelId'] is! String) {
      throw const FormatException('duel offer');
    }
    final config = DuelConfig.fromJson(json['config']);
    final lane = json['lane'];
    return DuelOffer(
      duelId: json['duelId'] as String,
      kind: DuelKind.parse(json['kind']),
      config: config,
      lane: lane == null ? null : DuelLane.fromJson(lane, config.mode),
      opponent: DuelOpponent.fromJson(json['opponent']),
    );
  }
}

/// The server's answer to a run (`POST /v1/duels/run`): for the second
/// player, the result; for a challenger, [waiting] until the friend plays.
final class DuelVerdict {
  const DuelVerdict({
    required this.duelId,
    required this.you,
    this.waiting = false,
    this.result,
    this.them,
    this.rated = false,
    this.ratingBefore,
    this.ratingAfter,
    this.ratingNow,
    this.provisional = true,
  });

  final String duelId;
  final DuelScore you;
  final bool waiting;

  /// 1 a win, 0.5 a draw, 0 a loss; `null` while waiting.
  final double? result;
  final DuelScore? them;
  final bool rated;
  final double? ratingBefore;
  final double? ratingAfter;

  /// The player's rating in the mode now (shown when the duel was unrated).
  final double? ratingNow;
  final bool provisional;

  factory DuelVerdict.fromJson(Object? json, DuelMode mode) {
    if (json is! Map || json['status'] != 'accepted') {
      throw const FormatException('duel verdict');
    }
    DuelScore? score(Object? s) => s is Map
        ? DuelScore(
            mode: mode,
            points: s['points'] as int,
            totalMs: s['ms'] as int,
          )
        : null;
    final rating = json['rating'];
    final r = rating is Map ? rating : const {};
    return DuelVerdict(
      duelId: json['duelId'] as String,
      you: score(json['you']) ?? (throw const FormatException('you')),
      waiting: json['waiting'] == true,
      result: (json['result'] as num?)?.toDouble(),
      them: score(json['them']),
      rated: json['rated'] == true,
      ratingBefore: (r['before'] as num?)?.toDouble(),
      ratingAfter: (r['after'] as num?)?.toDouble(),
      ratingNow: (r['current'] as num?)?.toDouble(),
      provisional: r['provisional'] != false,
    );
  }
}

/// What a server lists in its `/health` for duels (Phase 7 commit 0).
typedef DuelServerSupport = ({Set<DuelMode> modes, Set<int> rules});

/// The duel endpoints of the server (`server/lib/src/duel_endpoint.dart`).
/// Only the server's own answer is final: [DuelUnavailable] means "try
/// again later", [DuelRefused] means "never".
abstract interface class DuelClient {
  /// Matchmaking: the pool, practice, a rematch or a challenge.
  Future<DuelOffer> find(DuelMode mode, {String? rematchOf, String? challenge});

  /// A challenge waiting for the player.
  Future<DuelOffer> open(String duelId);

  /// The player's run of [duelId].
  Future<DuelVerdict> submit(String duelId, DuelMode mode, DuelRun run);

  /// The run as it stands, during the duel (plan v3.8): an abandoned duel
  /// is recorded as a loss from it after 24 hours. Best effort: a failure
  /// changes nothing on the device.
  Future<void> progress(String duelId, DuelRun run);

  /// The duel modes and duel rules the server lists (`/health`).
  Future<DuelServerSupport> support();
}

/// Refused for good (`{status: refused, reason}`): never resent.
class DuelRefused implements Exception {
  const DuelRefused(this.reason);
  final String reason;
  @override
  String toString() => 'DuelRefused($reason)';
}

/// Offline, a sleeping server, 5xx: try again later.
class DuelUnavailable implements Exception {
  const DuelUnavailable(this.detail);
  final String detail;
  @override
  String toString() => 'DuelUnavailable($detail)';
}

/// The player is a guest: online play needs a linked account (403).
class DuelAccountRequired implements Exception {
  const DuelAccountRequired();
}
