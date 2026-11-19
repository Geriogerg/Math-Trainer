import 'dart:async';

import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/models/session_kind.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/placement/placement.dart';
import 'package:math_trainer/core/domain/placement/placement_exercise_source.dart';
import 'package:math_trainer/core/domain/placement/placement_level_orchestrator.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';
import 'package:test/test.dart';

/// Never fires: the timeout is not under test here.
class _InertTimer implements Timer {
  @override
  void cancel() {}
  @override
  bool get isActive => true;
  @override
  int get tick => 0;
}

/// The placement through the real `SessionController`, as
/// `buildPlacementController` wires it (`composition_root.dart`).
void main() {
  const rules = currentPlacementRules;
  late InMemorySessionRepository repository;

  SessionController placement() => SessionController(
    config: SessionConfig(
      seed: 1763510400000,
      enabledTypes: placementTypes.toSet(),
      exerciseCount: rules.questionCount,
      levels: {
        for (final t in placementTypes) t: Level.whole(rules.startLevel),
      },
      kind: placementKindFor(rules),
    ),
    exerciseSource: PlacementExerciseSource(seed: 1763510400000, rules: rules),
    levelCacheOrchestrator: const PlacementLevelOrchestrator(rules: rules),
    repository: repository,
    playerId: 'new-player',
    // Constant clock: every answer takes 0 ms, a pass when right.
    clock: () => DateTime(2026, 11, 19),
    createTimer: (_, _) => _InertTimer(),
  );

  setUp(() => repository = InMemorySessionRepository());

  test('a full placement sets the four basic levels, nothing else, and is '
      'stored as a placement', () async {
    final controller = placement()..start();
    // Right on additions and multiplications, wrong on the others.
    var i = 0;
    while (controller.state.status == SessionStatus.inProgress) {
      final exercise = controller.state.currentExercise!;
      final right = i.isEven; // types alternate add, sub, mul, div
      controller.submitAnswer(
        right ? exercise.correctAnswer : exercise.correctAnswer + 1,
      );
      i++;
    }
    await controller.pendingPersistence;

    final levels = await repository.currentLevels('new-player');
    expect(levels.keys, unorderedEquals(placementTypes));
    // 5 passes: 3500 + 2500 + 1250 + 625 + 312 + 156.
    expect(levels[placementTypes[0]]!.level, Level.fromHundredths(8343));
    expect(levels[placementTypes[1]]!.level, Level.floor);
    expect(levels[placementTypes[2]]!.level, Level.fromHundredths(8343));
    expect(levels[placementTypes[3]]!.level, Level.floor);
    for (final entry in levels.values) {
      expect(entry.sessionsPlayed, rules.sessionsPlayedAfter);
    }

    final stored = await repository.recentSessions('new-player');
    expect(stored.single.kind, SessionKind.placementV2);
    expect(
      (await repository.answersForSession(stored.single.id)).length,
      rules.questionCount,
    );
  });

  test(
    'an interrupted placement keeps its answers but sets no level',
    () async {
      final controller = placement()..start();
      for (var i = 0; i < 5; i++) {
        controller.submitAnswer(
          controller.state.currentExercise!.correctAnswer,
        );
      }
      controller.abandon();
      await controller.pendingPersistence;

      expect(await repository.currentLevels('new-player'), isEmpty);
      final stored = await repository.recentSessions('new-player');
      expect(stored.single.kind, SessionKind.placementV2);
      expect(controller.lastLevelUpdates, isNull);
    },
  );
}
