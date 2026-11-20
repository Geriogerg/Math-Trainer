import 'dart:async';

import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/session_repository.dart';

/// The signed-in player's level cache as the server holds it (Phase 3a
/// commit 2). The app reads it from Supabase (`my_server_levels()`); tests
/// use fakes. Throws on any failure (offline, signed out, bad answer).
abstract interface class ServerLevelsSource {
  Future<Map<ExerciseType, LevelCacheEntry>> fetch();
}

enum LevelSyncOutcome {
  /// The server's levels differed: they replaced the local cache.
  adopted,

  /// Local and server levels already agree.
  unchanged,

  /// Sessions still wait to be uploaded: the local levels are ahead of the
  /// server's and are the ones the next upload chains from.
  pendingUploads,

  /// No answer in time, or a failure: local levels, as before.
  unavailable,
}

/// Before a game (plan v2.3, Phase 3a commit 2): when every local session is
/// settled (accepted or refused), the game must start from the server's
/// levels — a game started from anything else is refused (`levelsMismatch`).
/// They differ after a game on another device, or after a refusal.
///
/// Never while uploads are pending: those sessions chain from the local
/// levels, and adopting the server's (which lack them) would roll local
/// progress back and get the next game refused. Never longer than
/// [timeout]: a game does not wait for the network.
Future<LevelSyncOutcome> syncLevelsBeforeGame({
  required SessionRepository repository,
  required ServerLevelsSource source,
  required String playerId,
  Duration timeout = const Duration(seconds: 2),
}) async {
  if ((await repository.pendingUploads(playerId)).isNotEmpty) {
    return LevelSyncOutcome.pendingUploads;
  }
  final Map<ExerciseType, LevelCacheEntry> server;
  try {
    server = await source.fetch().timeout(timeout);
  } on Exception catch (_) {
    return LevelSyncOutcome.unavailable;
  }
  final local = await repository.currentLevels(playerId);
  if (_sameLevels(local, server)) return LevelSyncOutcome.unchanged;
  await repository.replaceLevelCache(playerId, server);
  return LevelSyncOutcome.adopted;
}

/// What the server checks and computes from: the level and the session
/// count (the calibration boost). `updatedAt` alone never forces a write.
bool _sameLevels(
  Map<ExerciseType, LevelCacheEntry> a,
  Map<ExerciseType, LevelCacheEntry> b,
) {
  if (a.length != b.length) return false;
  for (final MapEntry(key: type, value: entry) in a.entries) {
    final other = b[type];
    if (other == null ||
        other.level != entry.level ||
        other.sessionsPlayed != entry.sessionsPlayed) {
      return false;
    }
  }
  return true;
}

/// The server's levels read ahead of the first game (Phase 5.1 commit 1):
/// [start] fetches them while the player is still on the Play tab, and the
/// next [fetch] — the one `syncLevelsBeforeGame` makes when Start is
/// pressed — gets that answer instead of a new round trip.
///
/// The early answer is used once, and only if it still describes the
/// server: nothing was waiting for upload when it was read (pending
/// sessions are about to change the server's levels), and no session has
/// been stored on this device since (its upload changes them too). Anything
/// else reads the server again, as before. A game on another device in
/// between is the one case it misses — exactly as a read made at Start
/// would miss a game finishing there a second later; the server refuses
/// the next session and the app adopts the levels it sends.
class PrefetchedServerLevels implements ServerLevelsSource {
  PrefetchedServerLevels({
    required this.source,
    required this.repository,
    required this.playerId,
  });

  final ServerLevelsSource source;
  final SessionRepository repository;
  final String playerId;

  /// The read in flight or done, and the latest stored session when it
  /// started (`null`: none).
  ({Future<Map<ExerciseType, LevelCacheEntry>> levels, String? latest})? _early;

  /// Starts the early read, unless sessions wait for upload. Never throws:
  /// a failure only means [fetch] reads again.
  Future<void> start() async {
    try {
      if ((await repository.pendingUploads(playerId)).isNotEmpty) return;
      final latest = await repository.recentSessions(playerId, limit: 1);
      final levels = source.fetch();
      // Its error, if any, is seen by whoever awaits it in [fetch].
      levels.ignore();
      _early = (
        levels: levels,
        latest: latest.isEmpty ? null : latest.first.id,
      );
    } on Exception catch (_) {
      _early = null;
    }
  }

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> fetch() async {
    final early = _early;
    _early = null;
    if (early != null) {
      final latest = await repository.recentSessions(playerId, limit: 1);
      if ((latest.isEmpty ? null : latest.first.id) == early.latest) {
        return early.levels;
      }
    }
    return source.fetch();
  }
}
