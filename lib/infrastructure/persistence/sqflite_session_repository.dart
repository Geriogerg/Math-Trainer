import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/domain/models/operation_type.dart';
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
  }) async {
    await _database.transaction((txn) async {
      await txn.insert('sessions', _sessionToRow(session));
      for (final answer in answers) {
        await txn.insert('answers', _answerToRow(answer));
      }
    });
  }

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) async {
    final rows = await _database.query('sessions', orderBy: 'created_at DESC', limit: limit);
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

  Map<String, Object?> _sessionToRow(PersistedSession session) {
    return {
      'id': session.id,
      'player_id': session.playerId,
      'seed': session.seed,
      'operation_types': jsonEncode(session.operationTypes.map((type) => type.name).toList()),
      'exercise_count': session.exerciseCount,
      'total_score': session.totalScore,
      'created_at': session.createdAt.toIso8601String(),
      'synced_at': session.syncedAt?.toIso8601String(),
    };
  }

  PersistedSession _sessionFromRow(Map<String, Object?> row) {
    final operationTypeNames = (jsonDecode(row['operation_types'] as String) as List).cast<String>();
    final syncedAt = row['synced_at'] as String?;
    return PersistedSession(
      id: row['id'] as String,
      playerId: row['player_id'] as String,
      seed: row['seed'] as int,
      operationTypes: operationTypeNames.map(OperationType.values.byName).toList(),
      exerciseCount: row['exercise_count'] as int,
      totalScore: row['total_score'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
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
      'submitted_value': answer.submittedValue.toDouble(),
      'is_correct': answer.isCorrect ? 1 : 0,
      'elapsed_ms': answer.elapsedMs,
      'created_at': answer.createdAt.toIso8601String(),
      'synced_at': answer.syncedAt?.toIso8601String(),
    };
  }

  PersistedAnswer _answerFromRow(Map<String, Object?> row) {
    final operands = (jsonDecode(row['operands_json'] as String) as Map).cast<String, Object?>();
    final syncedAt = row['synced_at'] as String?;
    return PersistedAnswer(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      exerciseType: row['exercise_type'] as String,
      operationType: row['operation_type'] as String,
      operands: operands,
      submittedValue: row['submitted_value'] as num,
      isCorrect: (row['is_correct'] as int) == 1,
      elapsedMs: row['elapsed_ms'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      syncedAt: syncedAt == null ? null : DateTime.parse(syncedAt),
    );
  }
}
