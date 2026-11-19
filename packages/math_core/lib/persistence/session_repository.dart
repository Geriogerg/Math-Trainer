import 'level_cache_entry.dart';
import '../models/exercise_type.dart';
import 'persisted_answer.dart';
import 'persisted_session.dart';

/// The domain never knows the storage implementation (sqflite, memory, ...)
/// — only this interface. Every method is asynchronous even when a local
/// implementation is synchronous, so the call chain need not be rewritten
/// the day the network comes in.
abstract class SessionRepository {
  /// Writes [session], [answers] and the level cache update in one atomic
  /// operation: the cache must never be ahead of or behind the session that
  /// produced it.
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  });

  /// Sessions of [playerId], most recent first.
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  });

  Future<List<PersistedAnswer>> answersForSession(String sessionId);

  /// Whether [playerId] has at least one session played to its last
  /// question, game or placement. An interrupted session does not count
  /// (owner, end of Phase 1): an interrupted placement is offered again.
  Future<bool> hasCompletedSession(String playerId);

  /// Current state of the level cache for [playerId]. Only includes
  /// operations played at least once — the caller decides the default
  /// level for a missing operation (see `doc/decisions.md`).
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId);

  /// Average response time per operation, over the whole history of
  /// [playerId]. Timeouts included — same rules as
  /// `SessionResult.averageElapsedMs` (already used on the result screen),
  /// so both screens tell the same story. Aggregated in SQL on the `sqflite`
  /// side: does not degrade as history grows, unlike an `answersForSession`
  /// called once per session (`doc/decisions.md` — loading history without
  /// loading all of it).
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId);

  /// Sessions of [playerId] created from [since] (inclusive), oldest first.
  /// A date-bounded window rather than SQL aggregation: `levels` is stored
  /// as JSON, so there is no numeric column to aggregate into a
  /// per-operation level at a given time — but the read stays bounded,
  /// never the full history.
  Future<List<PersistedSession>> sessionsSince(String playerId, DateTime since);

  /// Hands to [toPlayerId] everything played under [fromPlayerId]
  /// (sessions, hence their answers, and the level cache) in one atomic
  /// operation. Used at sign-in: games played under the device's local id,
  /// from before accounts, go to the first account that signs in on it
  /// (`doc/online.md`). Does nothing if [toPlayerId] already has data here
  /// — never a merge of two histories, whose level caches would contradict
  /// each other.
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  });

  /// Sessions of [playerId] still to upload (plan, Phase 2 commit 5),
  /// oldest first — the server checks that levels chain from one session
  /// to the next, so order matters: never accepted (`syncedAt == null`) and
  /// never refused.
  Future<List<PersistedSession>> pendingUploads(String playerId);

  /// The server accepted [sessionId] at [syncedAt] (UTC): the session and
  /// its answers carry it from now on.
  Future<void> markSynced(String sessionId, DateTime syncedAt);

  /// The server refused [sessionId] for good ([reason], a rejection name):
  /// never sent again, still in the player's history.
  Future<void> markUploadRefused(String sessionId, String reason);

  /// Replaces [playerId]'s whole level cache with [levels] — the server's,
  /// after it refused a session whose levels did not chain from its own
  /// (another device, or history from before uploads). Atomic.
  Future<void> replaceLevelCache(
    String playerId,
    Map<ExerciseType, LevelCacheEntry> levels,
  );

  /// Deletes everything stored here for [playerId] — sessions, their
  /// answers, the level cache — in one atomic operation (account deletion,
  /// plan section 6.3). Other players on this device are untouched.
  Future<void> deletePlayerData(String playerId);
}
