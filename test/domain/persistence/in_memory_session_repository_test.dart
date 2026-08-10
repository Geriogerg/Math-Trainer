import 'package:math_trainer/core/domain/leveling/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:test/test.dart';

void main() {
  PersistedSession session(String id, {required DateTime createdAt, String playerId = 'player-1'}) {
    return PersistedSession(
      id: id,
      playerId: playerId,
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 10,
      totalScore: 100,
      levels: const {},
      createdAt: createdAt,
    );
  }

  PersistedAnswer answer(String id, String sessionId) {
    return PersistedAnswer(
      id: id,
      sessionId: sessionId,
      exerciseType: 'arithmetic',
      operationType: 'addition',
      operands: const {'operandA': 4, 'operandB': 3},
      submittedValue: 7,
      isCorrect: true,
      elapsedMs: 1000,
      createdAt: DateTime.utc(2026, 8, 8),
    );
  }

  group('InMemorySessionRepository', () {
    test('recordSession puis answersForSession retrouve exactement ce qui a été écrit', () async {
      final repository = InMemorySessionRepository();
      final s = session('session-1', createdAt: DateTime.utc(2026, 8, 8));
      final answers = [answer('answer-1', 'session-1'), answer('answer-2', 'session-1')];

      await repository.recordSession(session: s, answers: answers, levelUpdates: const {});
      final result = await repository.answersForSession('session-1');

      expect(result, equals(answers));
    });

    test('answersForSession ne retourne que les réponses de la session demandée', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
        answers: [answer('answer-1', 'session-1')],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('session-2', createdAt: DateTime.utc(2026, 8, 9)),
        answers: [answer('answer-2', 'session-2')],
        levelUpdates: const {},
      );

      final result = await repository.answersForSession('session-1');

      expect(result.map((a) => a.id), equals(['answer-1']));
    });

    test('recentSessions trie du plus récent au plus ancien et respecte la limite', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('oldest', createdAt: DateTime.utc(2026, 8, 1)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('newest', createdAt: DateTime.utc(2026, 8, 10)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('middle', createdAt: DateTime.utc(2026, 8, 5)),
        answers: const [],
        levelUpdates: const {},
      );

      final result = await repository.recentSessions(limit: 2);

      expect(result.map((s) => s.id), equals(['newest', 'middle']));
    });

    test('currentLevels est vide pour un joueur jamais joué', () async {
      final repository = InMemorySessionRepository();

      expect(await repository.currentLevels('unknown-player'), isEmpty);
    });

    test('currentLevels retrouve ce qui a été écrit via recordSession', () async {
      final repository = InMemorySessionRepository();
      final entry = LevelCacheEntry(level: 42, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 8, 8));

      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
        answers: const [],
        levelUpdates: {ExerciseType.addition: entry},
      );
      final levels = await repository.currentLevels('player-1');

      expect(levels[ExerciseType.addition]?.level, 42);
      expect(levels[ExerciseType.addition]?.sessionsPlayed, 1);
    });

    test('currentLevels ne mélange pas les joueurs', () async {
      final repository = InMemorySessionRepository();
      final entry = LevelCacheEntry(level: 77, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 8, 8));

      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8), playerId: 'player-a'),
        answers: const [],
        levelUpdates: {ExerciseType.addition: entry},
      );

      expect(await repository.currentLevels('player-b'), isEmpty);
    });
  });
}
