import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/persisted_answer.dart';
import '../../core/domain/persistence/persisted_session.dart';
import '../../core/domain/persistence/session_repository.dart';

class SqfliteSessionRepository implements SessionRepository {
  SqfliteSessionRepository(this._database);

  final Database _database;

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) async {
    await _database.transaction((txn) async {
      await txn.insert('sessions', _sessionToRow(session));
      for (final answer in answers) {
        await txn.insert('answers', _answerToRow(answer));
      }
      for (final entry in levelUpdates.entries) {
        await txn.insert(
          'player_levels',
          _levelCacheToRow(session.playerId, entry.key, entry.value),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) async {
    final rows = await _database.query(
      'sessions',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) async {
    final rows = await _database.query(
      'answers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    return rows.map(_answerFromRow).toList();
  }

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(
    String playerId,
  ) async {
    final rows = await _database.query(
      'player_levels',
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
    return {
      for (final row in rows)
        ExerciseType.values.byName(
          row['exercise_type'] as String,
        ): LevelCacheEntry(
          level: row['level'] as int,
          sessionsPlayed: row['sessions_played'] as int,
          updatedAt: DateTime.parse(row['updated_at'] as String),
        ),
    };
  }

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(
    String playerId,
  ) async {
    // `operation_type`, not `exercise_type`: for an arithmetic variant,
    // `exercise_type` is always the literal 'arithmetic'
    // (`exercise_codec.dart`) — `operation_type` carries the name usable as
    // an `ExerciseType` (addition/subtraction/... or the variant's name for
    // the other three families, where both columns match).
    final rows = await _database.rawQuery(
      '''
      SELECT a.operation_type AS operation_type, AVG(a.elapsed_ms) AS avg_elapsed_ms
      FROM answers a
      JOIN sessions s ON s.id = a.session_id
      WHERE s.player_id = ?
      GROUP BY a.operation_type
      ''',
      [playerId],
    );
    return {
      for (final row in rows)
        ExerciseType.values.byName(row['operation_type'] as String):
            (row['avg_elapsed_ms'] as num).toDouble(),
    };
  }

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) async {
    final rows = await _database.query(
      'sessions',
      where: 'player_id = ? AND created_at >= ?',
      whereArgs: [playerId, since.toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return rows.map(_sessionFromRow).toList();
  }

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {
    await _database.transaction((txn) async {
      // `answers` has no `player_id`: linked through `session_id`, answers
      // follow their session without rewriting anything.
      final targetRows = await txn.rawQuery(
        '''
        SELECT 1 FROM sessions WHERE player_id = ?
        UNION ALL
        SELECT 1 FROM player_levels WHERE player_id = ?
        LIMIT 1
        ''',
        [toPlayerId, toPlayerId],
      );
      if (targetRows.isNotEmpty) return;
      for (final table in ['sessions', 'player_levels']) {
        await txn.update(
          table,
          {'player_id': toPlayerId},
          where: 'player_id = ?',
          whereArgs: [fromPlayerId],
        );
      }
    });
  }

  Map<String, Object?> _sessionToRow(PersistedSession session) {
    return {
      'id': session.id,
      'player_id': session.playerId,
      'seed': session.seed,
      'operation_types': jsonEncode(
        session.enabledTypes.map((type) => type.name).toList(),
      ),
      'exercise_count': session.exerciseCount,
      'total_score': session.totalScore,
      'levels_json': jsonEncode(
        session.levels.map((type, level) => MapEntry(type.name, level)),
      ),
      'overall_level_after': session.overallLevelAfter,
      'created_at': session.createdAt.toIso8601String(),
      'synced_at': session.syncedAt?.toIso8601String(),
    };
  }

  PersistedSession _sessionFromRow(Map<String, Object?> row) {
    final typeNames = (jsonDecode(row['operation_types'] as String) as List)
        .cast<String>();
    final levelsJson = (jsonDecode(row['levels_json'] as String) as Map)
        .cast<String, Object?>();
    final syncedAt = row['synced_at'] as String?;
    return PersistedSession(
      id: row['id'] as String,
      playerId: row['player_id'] as String,
      seed: row['seed'] as int,
      enabledTypes: typeNames.map(ExerciseType.values.byName).toSet(),
      exerciseCount: row['exercise_count'] as int,
      totalScore: row['total_score'] as int,
      levels: levelsJson.map(
        (name, level) =>
            MapEntry(ExerciseType.values.byName(name), level as int),
      ),
      createdAt: DateTime.parse(row['created_at'] as String),
      overallLevelAfter: (row['overall_level_after'] as num?)?.toDouble(),
      syncedAt: syncedAt == null ? null : DateTime.parse(syncedAt),
    );
  }

  Map<String, Object?> _answerToRow(PersistedAnswer answer) {
    return {
      'id': answer.id,
      'session_id': answer.sessionId,
      'exercise_type': answer.exerciseType,
      'operation_type': answer.operationType,
      'operands_json': jsonEncode(answer.operands),
      'submitted_value': answer.submittedValue,
      'is_correct': answer.isCorrect ? 1 : 0,
      'elapsed_ms': answer.elapsedMs,
      'created_at': answer.createdAt.toIso8601String(),
      'synced_at': answer.syncedAt?.toIso8601String(),
    };
  }

  PersistedAnswer _answerFromRow(Map<String, Object?> row) {
    final operands = (jsonDecode(row['operands_json'] as String) as Map)
        .cast<String, Object?>();
    final syncedAt = row['synced_at'] as String?;
    return PersistedAnswer(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      exerciseType: row['exercise_type'] as String,
      operationType: row['operation_type'] as String,
      operands: operands,
      submittedValue: (row['submitted_value'] as num).toInt(),
      isCorrect: (row['is_correct'] as int) == 1,
      elapsedMs: row['elapsed_ms'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      syncedAt: syncedAt == null ? null : DateTime.parse(syncedAt),
    );
  }

  Map<String, Object?> _levelCacheToRow(
    String playerId,
    ExerciseType type,
    LevelCacheEntry entry,
  ) {
    return {
      'player_id': playerId,
      'exercise_type': type.name,
      'level': entry.level,
      'sessions_played': entry.sessionsPlayed,
      'updated_at': entry.updatedAt.toIso8601String(),
    };
  }
}
