import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:test/test.dart';

void main() {
  const exercise = ArithmeticExercise(
    operandA: 1,
    operandB: 1,
    operationType: OperationType.addition,
  );

  List<AnswerResult> correctOutcomes(
    int count, {
    ExerciseType type = ExerciseType.addition,
  }) {
    final typedExercise = type == ExerciseType.addition
        ? exercise
        : ArithmeticExercise(
            operandA: 1,
            operandB: 1,
            operationType: OperationType.subtraction,
          );
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
    test(
      'one entry per operation answered, counted on from the cache',
      () async {
        final repository = InMemorySessionRepository();
        final updates = await const LevelCacheOrchestrator().computeUpdates(
          outcomes: [
            ...correctOutcomes(4),
            ...correctOutcomes(4, type: ExerciseType.subtraction),
          ],
          frozenLevels: {
            ExerciseType.addition: Level.zero,
            ExerciseType.subtraction: Level.zero,
          },
          repository: repository,
          playerId: 'test-player',
          now: DateTime.utc(2026, 8, 8),
          rulesVersion: RulesVersion.current,
        );
        expect(updates.keys, {ExerciseType.addition, ExerciseType.subtraction});
        expect(updates[ExerciseType.addition]!.sessionsPlayed, 1);
      },
    );

    test('the frozen level passed in is the starting point, never the cache '
        'one', () async {
      const orchestrator = LevelCacheOrchestrator();
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
          ExerciseType.addition: LevelCacheEntry(
            level: Level.whole(80),
            sessionsPlayed: 3,
            updatedAt: now,
          ),
        },
      );

      final updates = await orchestrator.computeUpdates(
        outcomes: correctOutcomes(8),
        frozenLevels: {ExerciseType.addition: Level.whole(50)},
        repository: repository,
        playerId: 'test-player',
        now: now,
        rulesVersion: RulesVersion.current,
      );

      // 50 + 3 (8 fluent answers), not 80 + 3; counted on from the cache.
      expect(updates[ExerciseType.addition]?.level, Level.whole(53));
      expect(updates[ExerciseType.addition]?.sessionsPlayed, 4);
    });
  });
}
