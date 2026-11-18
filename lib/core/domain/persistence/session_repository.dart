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
}
