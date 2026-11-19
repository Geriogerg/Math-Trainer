import '../leveling/level.dart';
import '../models/exercise_type.dart';

/// A board: overall (`type == null`) or one operation (plan 6.4).
class LeaderboardBoard {
  const LeaderboardBoard.overall() : type = null;
  const LeaderboardBoard.of(ExerciseType this.type);

  final ExerciseType? type;

  /// The name the server functions take (`leaderboard_top(board)`).
  String get key => type?.name ?? 'overall';

  /// Overall first, then the operations in their usual order.
  static List<LeaderboardBoard> get all => [
    const LeaderboardBoard.overall(),
    for (final t in ExerciseType.values) LeaderboardBoard.of(t),
  ];

  @override
  bool operator ==(Object other) =>
      other is LeaderboardBoard && other.type == type;

  @override
  int get hashCode => type.hashCode;
}

/// One row: what the server shows of a player — rank, name, level.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.level,
    required this.isMe,
    this.playerId,
  });

  /// Who to report (`reportName`); public like the name it goes with.
  final String? playerId;

  final int rank;

  /// `null`: the player chose no name.
  final String? name;
  final Level level;
  final bool isMe;
}

/// Why the caller is not on a board (`leaderboard_around_me`).
enum NotRankedReason {
  signedOut,
  noSessions,
  notEnoughSessions,
  inactive,

  /// Only linked players appear (plan 6.3; Phase 2 commit 10).
  notLinked,

  /// A reason this build does not know (a newer server).
  other,
}

/// The caller's standing on a board.
sealed class Standing {
  const Standing();
}

final class Ranked extends Standing {
  const Ranked({
    required this.rank,
    required this.total,
    required this.topPercent,
    required this.level,
    required this.neighbours,
  });

  final int rank;
  final int total;

  /// "Top N %": the share of the board at or above this rank.
  final int topPercent;
  final Level level;

  /// Five above, the caller, five below (fewer at the ends).
  final List<LeaderboardEntry> neighbours;
}

final class NotRanked extends Standing {
  const NotRanked({required this.reason, this.sessionsNeeded = 0});

  final NotRankedReason reason;

  /// Counted sessions still missing on this board (0 if not the issue).
  final int sessionsNeeded;
}

/// Reads the boards — implemented on Supabase (`infrastructure/backend/`).
/// Throws on failure (offline...): the screen offers a retry.
abstract interface class LeaderboardRepository {
  Future<List<LeaderboardEntry>> top(LeaderboardBoard board);
  Future<Standing> aroundMe(LeaderboardBoard board);

  /// Reports [playerId]'s current name (Phase 2 commit 9); a repeat
  /// changes nothing. Throws on failure.
  Future<void> reportName(String playerId);
}

/// `leaderboard_top`'s JSON. Throws [FormatException] on anything else.
List<LeaderboardEntry> leaderboardEntriesFromJson(Object? json) {
  if (json is! List) throw const FormatException('entries is not a list');
  return [for (final e in json) _entry(e)];
}

/// `leaderboard_around_me`'s JSON. Throws [FormatException].
Standing standingFromJson(Object? json) {
  if (json is! Map) throw const FormatException('standing is not an object');
  if (json['eligible'] == true) {
    return Ranked(
      rank: _int(json, 'rank'),
      total: _int(json, 'total'),
      topPercent: _int(json, 'topPercent'),
      level: _level(json['level']),
      neighbours: leaderboardEntriesFromJson(json['neighbours'] ?? const []),
    );
  }
  final reason = NotRankedReason.values
      .where((r) => r.name == json['reason'])
      .firstOrNull;
  final needed = json['sessionsNeeded'];
  return NotRanked(
    reason: reason ?? NotRankedReason.other,
    sessionsNeeded: needed is int ? needed : 0,
  );
}

LeaderboardEntry _entry(Object? e) {
  if (e is! Map) throw const FormatException('entry is not an object');
  final name = e['name'];
  final playerId = e['playerId'];
  return LeaderboardEntry(
    playerId: playerId is String ? playerId : null,
    rank: _int(e, 'rank'),
    name: name is String && name.trim().isNotEmpty ? name : null,
    level: _level(e['level']),
    isMe: e['isMe'] == true,
  );
}

int _int(Map<Object?, Object?> m, String key) {
  final v = m[key];
  if (v is! int) throw FormatException('$key is not an integer');
  return v;
}

Level _level(Object? v) {
  if (v is! int) throw const FormatException('level is not an integer');
  try {
    return Level.fromHundredths(v);
  } on ArgumentError {
    throw FormatException('level $v out of range');
  }
}
