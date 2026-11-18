import 'package:math_trainer/core/domain/leveling/level_cache_orchestrator.dart';
import 'package:math_trainer/core/domain/models/answer_result.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:test/test.dart';

void main() {
  const exercise = ArithmeticExercise(operandA: 1, operandB: 1, operationType: OperationType.addition);

  List<AnswerResult> correctOutcomes(int count, {ExerciseType type = ExerciseType.addition}) {
    final typedExercise = type == ExerciseType.addition
        ? exercise
        : ArithmeticExercise(operandA: 1, operandB: 1, operationType: OperationType.subtraction);
    return List.generate(
      count,
      (_) => AnswerResult(
        exercise: typedExercise,
        submittedValue: 2,
        isCorrect: true,
        elapsedMs: 0,
        answeredAt: DateTime.utc(2024),
      ),
    );
  }

  group('LevelCacheOrchestrator', () {
    test('fewer than n_min answers for a type: no entry in the result', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();

      final updates = await orchestrator.computeUpdates(
        outcomes: correctOutcomes(3),
        frozenLevels: {ExerciseType.addition: 50},
        repository: repository,
        playerId: 'test-player',
        now: DateTime.utc(2026, 8, 8),
      );

      expect(updates, isEmpty);
    });

    test('at least n_min right and fast answers: the level rises (calibration, never '
        'played before)', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();

      final updates = await orchestrator.computeUpdates(
        outcomes: correctOutcomes(4),
        frozenLevels: {ExerciseType.addition: 50},
        repository: repository,
        playerId: 'test-player',
        now: DateTime.utc(2026, 8, 8),
      );

      // Same scenario as the LevelUpdater test of commit A (step 4.2): from
      // 50, n_min right and instant answers, calibration confidence → 53.
      expect(updates[ExerciseType.addition]?.level, 53);
      expect(updates[ExerciseType.addition]?.sessionsPlayed, 1);
    });

    test('a player with 3 recent sessions on this type gets normal confidence, '
        'not calibration', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();
      final now = DateTime.utc(2026, 8, 8);

      await repository.recordSession(
        session: PersistedSession(
          id: 'session-0',
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 0,
          levels: const {},
          createdAt: now,
        ),
        answers: const [],
        levelUpdates: {
          ExerciseType.addition: LevelCacheEntry(level: 50, sessionsPlayed: 3, updatedAt: now),
        },
      );

      final updates = await orchestrator.computeUpdates(
        outcomes: correctOutcomes(8),
        frozenLevels: {ExerciseType.addition: 50},
        repository: repository,
        playerId: 'test-player',
        now: now,
      );

      // Normal confidence (K_haut without multiplier): +1, not +3 as in
      // calibration (see LevelUpdater: normal → 51, calibration → 53).
      expect(updates[ExerciseType.addition]?.level, 51);
      expect(updates[ExerciseType.addition]?.sessionsPlayed, 4);
    });

    test('a type under n_min does not prevent updating another type above it', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();

      final updates = await orchestrator.computeUpdates(
        outcomes: [...correctOutcomes(8), ...correctOutcomes(3, type: ExerciseType.subtraction)],
        frozenLevels: {ExerciseType.addition: 50, ExerciseType.subtraction: 50},
        repository: repository,
        playerId: 'test-player',
        now: DateTime.utc(2026, 8, 8),
      );

      expect(updates.containsKey(ExerciseType.addition), isTrue);
      expect(updates.containsKey(ExerciseType.subtraction), isFalse);
    });

    test('the frozen level passed in is the starting point, never the cache one '
        'lu en interne', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();
      final now = DateTime.utc(2026, 8, 8);

      // The cache says 80, but the session was generated at 50 (frozenLevels):
      // 50 must be the starting point of the computation.
      await repository.recordSession(
        session: PersistedSession(
          id: 'session-0',
          playerId: 'test-player',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 8,
          totalScore: 0,
          levels: const {},
          createdAt: now,
        ),
        answers: const [],
        levelUpdates: {
          ExerciseType.addition: LevelCacheEntry(level: 80, sessionsPlayed: 3, updatedAt: now),
        },
      );

      final updates = await orchestrator.computeUpdates(
        outcomes: correctOutcomes(8),
        frozenLevels: {ExerciseType.addition: 50},
        repository: repository,
        playerId: 'test-player',
        now: now,
      );

      expect(updates[ExerciseType.addition]?.level, 51); // 50 + 1, not 80 + 1
    });
  });
}
