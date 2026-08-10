import 'package:math_trainer/core/domain/generation/exercise_source.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';
import 'package:test/test.dart';

class _FixedExerciseSource implements ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

void main() {
  const exercises = [
    ArithmeticExercise(operandA: 2, operandB: 2, operationType: OperationType.addition),
    ArithmeticExercise(operandA: 5, operandB: 3, operationType: OperationType.addition),
    ArithmeticExercise(operandA: 9, operandB: 1, operationType: OperationType.addition),
  ];

  SessionController buildController({InMemorySessionRepository? repository}) {
    return SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: {ExerciseType.addition},
        exerciseCount: exercises.length,
        levels: {ExerciseType.addition: 50},
      ),
      exerciseSource: _FixedExerciseSource(exercises),
      repository: repository ?? InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
    );
  }

  group('SessionController', () {
    test('start() passe en cours et affiche le premier exercice', () {
      final controller = buildController();

      controller.start();

      expect(controller.state.status, SessionStatus.inProgress);
      expect(controller.state.currentExercise, exercises[0]);
      expect(controller.state.score, 0);
    });

    test('submitAnswer ignoré avant start()', () {
      final controller = buildController();

      controller.submitAnswer(4);

      expect(controller.state.status, SessionStatus.notStarted);
      expect(controller.state.outcomes, isEmpty);
    });

    test('enchaîne les exercices et calcule score/streak/résultat final', () {
      final controller = buildController();
      controller.start();

      controller.submitAnswer(4); // correct, exercises[0] : 2+2
      expect(controller.state.currentStreak, 1);
      expect(controller.state.score, 20); // base 10 + bonus vitesse max 10 (élapsé nul)
      expect(controller.state.currentExercise, exercises[1]);

      controller.submitAnswer(0); // incorrect, exercises[1] : 5+3=8
      expect(controller.state.currentStreak, 0);
      expect(controller.state.score, 20);
      expect(controller.state.currentExercise, exercises[2]);

      controller.submitAnswer(10); // correct, exercises[2] : 9+1
      expect(controller.state.status, SessionStatus.finished);
      expect(controller.state.currentExercise, isNull);

      final result = controller.result;
      expect(result.correctCount, 2);
      expect(result.outcomes.length, 3);
      expect(result.totalScore, controller.state.score);
    });

    test('persiste la session dans le repository une fois terminée', () async {
      final repository = InMemorySessionRepository();
      final controller = buildController(repository: repository);
      controller.start();

      controller.submitAnswer(4);
      controller.submitAnswer(0);
      controller.submitAnswer(10);

      // Laisse la persistance asynchrone (non attendue par submitAnswer) se
      // dérouler avant de vérifier le repository.
      await Future<void>.delayed(Duration.zero);

      final sessions = await repository.recentSessions();
      expect(sessions, hasLength(1));
      expect(sessions.single.playerId, 'test-player');
      expect(sessions.single.totalScore, controller.state.score);
      expect(sessions.single.levels, {ExerciseType.addition: 50});

      final answers = await repository.answersForSession(sessions.single.id);
      expect(answers, hasLength(3));
      expect(answers.map((a) => a.isCorrect), [true, false, true]);

      // 3 réponses < n_min (8) : le cache de niveau n'est pas touché.
      expect(await repository.currentLevels('test-player'), isEmpty);
    });

    test('une session avec au moins n_min réponses justes et rapides met à jour le cache de '
        'niveau (calibration, première fois sur cette opération)', () async {
      final repository = InMemorySessionRepository();
      final eightExercises = List.generate(
        8,
        (i) => ArithmeticExercise(operandA: i, operandB: 0, operationType: OperationType.addition),
      );
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 8,
          levels: {ExerciseType.addition: 50},
        ),
        exerciseSource: _FixedExerciseSource(eightExercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
      );

      controller.start();
      for (var i = 0; i < 8; i++) {
        controller.submitAnswer(i); // i + 0 = i : toujours correct
      }
      await Future<void>.delayed(Duration.zero);

      final levels = await repository.currentLevels('test-player');
      // Depuis niveau 50, 8 réponses justes et instantanées, confiance
      // « calibration » (première session sur cette opération) : 53 — même
      // scénario que le test `LevelUpdater` du commit B.
      expect(levels[ExerciseType.addition]?.level, 53);
      expect(levels[ExerciseType.addition]?.sessionsPlayed, 1);
    });

    test('restart() réinitialise complètement la session', () {
      final controller = buildController();
      controller.start();
      controller.submitAnswer(4);

      controller.restart();

      expect(controller.state.status, SessionStatus.notStarted);
      expect(controller.state.score, 0);
      expect(controller.state.outcomes, isEmpty);
      expect(controller.state.currentExercise, isNull);
    });
  });
}
