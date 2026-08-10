import '../leveling/level_cache_entry.dart';
import '../models/exercise_type.dart';
import 'persisted_answer.dart';
import 'persisted_session.dart';
import 'session_repository.dart';

/// Implémentation de référence, Dart pur, sans I/O : sert de double de test
/// pour tout code qui dépend de [SessionRepository], et de repli sur web où
/// sqflite n'a pas d'implémentation native.
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
    _levelsByPlayer.putIfAbsent(session.playerId, () => {}).addAll(levelUpdates);
  }

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) async {
    final sorted = [..._sessions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) async {
    return _answers.where((answer) => answer.sessionId == sessionId).toList();
  }

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) async {
    return Map.of(_levelsByPlayer[playerId] ?? {});
  }
}
