import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// Phase 3a commit 7: the first game on never-played operations is a short
/// placement on them; the next game plays the whole selection.
void main() {
  late InMemorySessionRepository repository;
  late AppEnvironment environment;

  setUp(() async {
    repository = InMemorySessionRepository();
    environment = AppEnvironment(
      repository: repository,
      playerId: 'p',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );
    await repository.replaceLevelCache('p', {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.whole(30),
        sessionsPlayed: 5,
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    });
  });

  Future<void> playThrough(SessionController controller) async {
    controller.start();
    var i = 0;
    while (controller.state.status == SessionStatus.inProgress) {
      final q = controller.state.currentExercise!;
      final last = i == controller.config.exerciseCount - 1;
      // Right, except the last answer (no 1 s correction timer then).
      controller.submitAnswer(last ? q.correctAnswer + 1 : q.correctAnswer);
      i++;
    }
    await controller.pendingPersistence;
    controller.dispose();
  }

  test('only the never-played operations are placed', () async {
    final controller = await buildSessionController(environment, {
      ExerciseType.addition,
      ExerciseType.power,
      ExerciseType.percentage,
    });
    expect(controller.config.kind, SessionKind.typePlacementV3);
    expect(controller.config.enabledTypes, {
      ExerciseType.power,
      ExerciseType.percentage,
    });
    expect(controller.config.exerciseCount, 10);
    expect(controller.config.levels, {
      ExerciseType.power: Level.whole(35),
      ExerciseType.percentage: Level.whole(35),
    });

    await playThrough(controller);
    final levels = await repository.currentLevels('p');
    expect(levels[ExerciseType.power]!.level.whole, greaterThan(35));
    expect(levels[ExerciseType.power]!.sessionsPlayed, 0);
    expect(levels[ExerciseType.addition]!.level, Level.whole(30));

    // Placed: the same selection now plays a game, from those levels.
    final next = await buildSessionController(environment, {
      ExerciseType.addition,
      ExerciseType.power,
      ExerciseType.percentage,
    });
    addTearDown(next.dispose);
    expect(next.config.kind, SessionKind.game);
    expect(
      next.config.levels[ExerciseType.power],
      levels[ExerciseType.power]!.level,
    );
  });

  test('an interrupted one sets nothing and comes back', () async {
    final controller = await buildSessionController(environment, {
      ExerciseType.squareRoot,
    });
    controller.start();
    controller.submitAnswer(controller.state.currentExercise!.correctAnswer);
    controller.abandon();
    await controller.pendingPersistence;
    controller.dispose();

    expect(
      (await repository.currentLevels(
        'p',
      )).containsKey(ExerciseType.squareRoot),
      isFalse,
    );
    final again = await buildSessionController(environment, {
      ExerciseType.squareRoot,
    });
    addTearDown(again.dispose);
    expect(again.config.kind, SessionKind.typePlacementV3);
  });
}
