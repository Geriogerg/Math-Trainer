import 'package:math_core/leveling/fluent_time.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/leveling/level_updates.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 11, 23, 9);

AnswerResult _answer(
  OperationType op, {
  required bool correct,
  required int ms,
}) => AnswerResult(
  exercise: ArithmeticExercise(operandA: 3, operandB: 1, operationType: op),
  submittedValue: correct ? (op == OperationType.addition ? 4 : 3) : 0,
  isCorrect: correct,
  elapsedMs: ms,
  answeredAt: _at,
);

void main() {
  final fluent = fluentTimeMs(ExerciseType.addition, Level.zero);
  final outcomes = [
    for (var i = 0; i < 4; i++) ...[
      _answer(OperationType.addition, correct: true, ms: fluent),
      _answer(OperationType.multiplication, correct: true, ms: fluent + 5000),
    ],
  ];

  test('rules v2: each operation moves by its own quality, from 0', () {
    final updates = gameLevelUpdates(
      outcomes: outcomes,
      frozenLevels: {
        ExerciseType.addition: Level.zero,
        ExerciseType.multiplication: Level.whole(10),
      },
      priorLevels: {
        ExerciseType.multiplication: LevelCacheEntry(
          level: Level.whole(10),
          sessionsPlayed: 2,
          updatedAt: DateTime.utc(2026, 11, 22),
        ),
      },
      now: _at,
      rulesVersion: RulesVersion.v2,
    );
    expect(updates[ExerciseType.addition]!.level, Level.fromHundredths(300));
    expect(updates[ExerciseType.addition]!.sessionsPlayed, 1);
    // All slow: q = 0.75, +1.2 — never a calibration or return boost.
    expect(
      updates[ExerciseType.multiplication]!.level,
      Level.fromHundredths(1120),
    );
    expect(updates[ExerciseType.multiplication]!.sessionsPlayed, 3);
    expect(updates[ExerciseType.multiplication]!.updatedAt, _at);
  });

  test('rules v2: a missing frozen level counts as 0', () {
    final updates = gameLevelUpdates(
      outcomes: outcomes,
      frozenLevels: const {},
      priorLevels: const {},
      now: _at,
      rulesVersion: RulesVersion.v2,
    );
    expect(updates[ExerciseType.addition]!.level, Level.fromHundredths(300));
    expect(
      updates[ExerciseType.multiplication]!.level,
      Level.fromHundredths(120),
    );
  });

  test('the orchestrator scores with its rules version', () async {
    final repository = InMemorySessionRepository();
    final updates = await LevelCacheOrchestrator(rulesVersion: RulesVersion.v2)
        .computeUpdates(
          outcomes: outcomes,
          frozenLevels: const {
            ExerciseType.addition: Level.zero,
            ExerciseType.multiplication: Level.zero,
          },
          repository: repository,
          playerId: 'p',
          now: _at,
        );
    expect(updates[ExerciseType.addition]!.level, Level.fromHundredths(300));
  });
}
