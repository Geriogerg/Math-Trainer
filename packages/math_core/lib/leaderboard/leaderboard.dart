import '../duel/duel_mode.dart';
import '../leveling/level.dart';
import '../models/exercise_type.dart';

/// A board: the main board (`type == null`, ranked on the main level —
/// the four basics, plan v2.9), one operation (plan 6.4), or a duel mode's
/// (plan v3.7, Phase 7: ranked on the mode's rating).
class LeaderboardBoard {
  const LeaderboardBoard.main() : type = null, duel = null;
  const LeaderboardBoard.of(ExerciseType this.type) : duel = null;
  const LeaderboardBoard.duel(DuelMode this.duel) : type = null;

  final ExerciseType? type;
  final DuelMode? duel;

  /// Ranked on a rating rather than a level.
  bool get isDuel => duel != null;

  /// The name the server functions take (`leaderboard_top(board)`,
  /// `duel_board_top(mode)`). The main board keeps the key `overall` it had
  /// before the main level existed: builds still cached by players ask for
  /// it by that name.
  String get key => duel?.name ?? type?.name ?? 'overall';

  /// The main board first, the three duel boards, then the operations in
  /// their usual order.
  static List<LeaderboardBoard> get all => [
    const LeaderboardBoard.main(),
    for (final mode in DuelMode.values) LeaderboardBoard.duel(mode),
    for (final t in ExerciseType.values) LeaderboardBoard.of(t),
  ];

  @override
  bool operator ==(Object other) =>
      other is LeaderboardBoard && other.type == type && other.duel == duel;

  @override
  int get hashCode => Object.hash(type, duel);
}

/// One row: what the server shows of a player — rank, name, and the level
/// (level boards) or the rating (duel boards).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    this.level,
    this.rating,
    required this.isMe,
    this.playerId,
  });

  /// Who to report (`reportName`); public like the name it goes with.
  final String? playerId;

  final int rank;

  /// `null`: the player chose no name.
  final String? name;

  /// A level board's value; `null` on a duel board.
  final Level? level;

  /// A duel board's value, in whole points; `null` on a level board.
  final int? rating;
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

  /// A duel board: no rated duel in the mode yet.
  noDuels,

  /// A duel board: fewer than 10 rated duels (`sessionsNeeded` more).
  provisional,

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
    this.level,
    this.rating,
    required this.neighbours,
  });

  final int rank;
  final int total;

  /// "Top N %": the share of the board at or above this rank.
  final int topPercent;

  /// The caller's level (level boards) or rating (duel boards).
  final Level? level;
  final int? rating;

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
      level: json['level'] == null ? null : _level(json['level']),
      rating: json['rating'] == null ? null : _int(json, 'rating'),
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
    level: e['level'] == null ? null : _level(e['level']),
    rating: e['rating'] == null ? null : _int(e, 'rating'),
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
