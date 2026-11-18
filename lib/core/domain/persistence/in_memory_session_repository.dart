import 'level_cache_entry.dart';
import '../models/exercise_type.dart';
import 'persisted_answer.dart';
import 'persisted_session.dart';
import 'session_repository.dart';

/// Reference implementation, pure Dart, no I/O: a test double for any code
/// depending on [SessionRepository]. No longer used by the app itself — the
/// web now has its SQLite database (`composition_root.dart`).
class InMemorySessionRepository implements SessionRepository {
  final List<PersistedSession> _sessions = [];
  final List<PersistedAnswer> _answers = [];
  final Map<String, Map<ExerciseType, LevelCacheEntry>> _levelsByPlayer = {};

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) async {
    _sessions.add(session);
    _answers.addAll(answers);
    _levelsByPlayer
        .putIfAbsent(session.playerId, () => {})
        .addAll(levelUpdates);
  }

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) async {
    final sorted =
        _sessions.where((session) => session.playerId == playerId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) async {
    return _answers.where((answer) => answer.sessionId == sessionId).toList();
  }

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(
    String playerId,
  ) async {
    return Map.of(_levelsByPlayer[playerId] ?? {});
  }

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(
    String playerId,
  ) async {
    final sessionIds = _sessions
        .where((session) => session.playerId == playerId)
        .map((session) => session.id)
        .toSet();
    final byType = <ExerciseType, List<int>>{};
    for (final answer in _answers) {
      if (!sessionIds.contains(answer.sessionId)) continue;
      // `operationType`, not `exerciseType`: see the matching comment in
      // SqfliteSessionRepository — 'arithmetic' is not an ExerciseType.
      final type = ExerciseType.values.byName(answer.operationType);
      byType.putIfAbsent(type, () => []).add(answer.elapsedMs);
    }
    return {
      for (final entry in byType.entries)
        entry.key: entry.value.reduce((a, b) => a + b) / entry.value.length,
    };
  }

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) async {
    final matching = _sessions.where(
      (session) =>
          session.playerId == playerId && !session.createdAt.isBefore(since),
    );
    return matching.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {
    final targetHasData =
        _levelsByPlayer.containsKey(toPlayerId) ||
        _sessions.any((session) => session.playerId == toPlayerId);
    if (targetHasData) return;
    for (var i = 0; i < _sessions.length; i++) {
      if (_sessions[i].playerId == fromPlayerId) {
        _sessions[i] = _sessions[i].copyWith(playerId: toPlayerId);
      }
    }
    final levels = _levelsByPlayer.remove(fromPlayerId);
    if (levels != null) _levelsByPlayer[toPlayerId] = levels;
  }
}
