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
      (_) => AnswerResult(exercise: typedExercise, submittedValue: 2, isCorrect: true, elapsedMs: 0),
    );
  }

  group('LevelCacheOrchestrator', () {
    test('moins de n_min réponses pour un type : aucune entrée dans le résultat', () async {
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

    test('au moins n_min réponses justes et rapides : le niveau monte (calibration, jamais '
        'joué avant)', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();

      final updates = await orchestrator.computeUpdates(
        outcomes: correctOutcomes(4),
        frozenLevels: {ExerciseType.addition: 50},
        repository: repository,
        playerId: 'test-player',
        now: DateTime.utc(2026, 8, 8),
      );

      // Même scénario que le test LevelUpdater du commit A (étape 4.2) : depuis
      // 50, n_min réponses justes et instantanées, confiance calibration → 53.
      expect(updates[ExerciseType.addition]?.level, 53);
      expect(updates[ExerciseType.addition]?.sessionsPlayed, 1);
    });

    test('un joueur avec 3 sessions déjà jouées récemment sur ce type obtient une confiance '
        'normale, pas calibration', () async {
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

      // Confiance normale (K_haut sans multiplicateur) : +1, pas +3 comme
      // en calibration (voir LevelUpdater : normal → 51, calibration → 53).
      expect(updates[ExerciseType.addition]?.level, 51);
      expect(updates[ExerciseType.addition]?.sessionsPlayed, 4);
    });

    test('un type sous n_min n\'empêche pas la mise à jour d\'un autre type au-dessus', () async {
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

    test('le niveau figé passé en paramètre sert de point de départ, jamais celui du cache '
        'lu en interne', () async {
      final orchestrator = LevelCacheOrchestrator();
      final repository = InMemorySessionRepository();
      final now = DateTime.utc(2026, 8, 8);

      // Le cache dit 80, mais la session a été générée avec 50 (frozenLevels) :
      // c'est 50 qui doit servir de point de départ au calcul.
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

      expect(updates[ExerciseType.addition]?.level, 51); // 50 + 1, pas 80 + 1
    });
  });
}
