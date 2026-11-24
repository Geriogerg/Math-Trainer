import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/input_device.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'session_rows.dart';

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
    return rows.map(sessionFromRow).toList();
  }

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) async {
    final rows = await _database.query(
      'answers',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      // The order they were given (inserted in order, one transaction): a
      // replay pairs answer i with question i.
      orderBy: 'rowid',
    );
    return rows.map(_answerFromRow).toList();
  }

  @override
  Future<List<StoredGame>> storedGames(String playerId) async {
    final sessions = await _database.query(
      'sessions',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'created_at, id',
    );
    // One query for every answer, grouped here: answer i pairs with
    // question i, in the order given (rowid).
    final answers = await _database.rawQuery(
      'SELECT a.* FROM answers a JOIN sessions s ON s.id = a.session_id '
      'WHERE s.player_id = ? ORDER BY a.rowid',
      [playerId],
    );
    final bySession = <String, List<PersistedAnswer>>{};
    for (final row in answers) {
      final answer = _answerFromRow(row);
      bySession.putIfAbsent(answer.sessionId, () => []).add(answer);
    }
    return [
      for (final row in sessions)
        (
          session: sessionFromRow(row),
          answers: bySession[row['id']] ?? const <PersistedAnswer>[],
        ),
    ];
  }

  @override
  Future<bool> hasCompletedSession(String playerId) async {
    // Interrupted = fewer answers than planned (`exercise_count` keeps the
    // planned count, `SessionController._persistCompletedSession`).
    final rows = await _database.rawQuery(
      '''
      SELECT 1 FROM sessions s
      WHERE s.player_id = ?
        AND (SELECT COUNT(*) FROM answers a WHERE a.session_id = s.id)
            >= s.exercise_count
      LIMIT 1
      ''',
      [playerId],
    );
    return rows.isNotEmpty;
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
          level: Level.fromHundredths(row['level'] as int),
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
    return rows.map(sessionFromRow).toList();
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

  @override
  Future<List<PersistedSession>> pendingUploads(String playerId) async {
    final rows = await _database.query(
      'sessions',
      where: 'player_id = ? AND synced_at IS NULL AND upload_refused IS NULL',
      whereArgs: [playerId],
      // Oldest first: levels chain from one session to the next.
      orderBy: 'created_at ASC, rowid ASC',
    );
    return rows.map(sessionFromRow).toList();
  }

  @override
  Future<void> markSynced(String sessionId, DateTime syncedAt) async {
    final at = syncedAt.toUtc().toIso8601String();
    await _database.transaction((txn) async {
      await txn.update(
        'sessions',
        {'synced_at': at},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await txn.update(
        'answers',
        {'synced_at': at},
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  @override
  Future<void> markUploadRefused(String sessionId, String reason) =>
      _database.update(
        'sessions',
        {'upload_refused': reason},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

  @override
  Future<void> replaceLevelCache(
    String playerId,
    Map<ExerciseType, LevelCacheEntry> levels,
  ) async {
    await _database.transaction((txn) async {
      await txn.delete(
        'player_levels',
        where: 'player_id = ?',
        whereArgs: [playerId],
      );
      for (final MapEntry(key: type, value: entry) in levels.entries) {
        await txn.insert(
          'player_levels',
          _levelCacheToRow(playerId, type, entry),
        );
      }
    });
  }

  @override
  Future<void> deletePlayerData(String playerId) async {
    await _database.transaction((txn) async {
      // Answers first: they reference their session (`session_id`).
      await txn.rawDelete(
        'DELETE FROM answers WHERE session_id IN '
        '(SELECT id FROM sessions WHERE player_id = ?)',
        [playerId],
      );
      for (final table in ['sessions', 'player_levels']) {
        await txn.delete(table, where: 'player_id = ?', whereArgs: [playerId]);
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
        session.levels.map(
          (type, level) => MapEntry(type.name, level.hundredths),
        ),
      ),
      'overall_level_after': session.overallLevelAfter,
      'kind': session.kind.name,
      'type_sequence': session.typeSequence == null
          ? null
          : jsonEncode([for (final t in session.typeSequence!) t.name]),
      'created_at': session.createdAt.toIso8601String(),
      'synced_at': session.syncedAt?.toIso8601String(),
      'app_version': session.appVersion,
      'rules_version': session.rulesVersion.number,
      'weak_spots': session.weakSpots.isEmpty
          ? null
          : jsonEncode([for (final item in session.weakSpots) item.key]),
    };
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
      'input_device': answer.inputDevice?.name,
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
      inputDevice: switch (row['input_device'] as String?) {
        null => null,
        final name => InputDevice.values.byName(name),
      },
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
      'level': entry.level.hundredths,
      'sessions_played': entry.sessionsPlayed,
      'updated_at': entry.updatedAt.toIso8601String(),
    };
  }
}
