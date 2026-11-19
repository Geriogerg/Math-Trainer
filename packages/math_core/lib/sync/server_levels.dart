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
