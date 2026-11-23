import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_updates.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/tiers/fluent_time.dart';
import 'package:test/test.dart';

void main() {
  test("the spec's fluent times, tier by tier (doc/levels.md, section 5)", () {
    final spec = {
      ExerciseType.addition: [4, 4, 5, 5, 6, 8, 9, 10, 12, 14],
      ExerciseType.subtraction: [4, 4, 5, 5, 6, 8, 9, 10, 12, 14],
      ExerciseType.multiplication: [4, 4, 6, 7, 8, 10, 12, 12, 15, 18],
      ExerciseType.division: [4, 5, 6, 7, 8, 10, 12, 12, 15, 18],
      ExerciseType.power: [4, 5, 6, 6, 8, 10, 12, 14, 16, 18],
      ExerciseType.squareRoot: [4, 5, 6, 6, 8, 10, 12, 14, 16, 18],
      ExerciseType.percentage: [4, 5, 6, 7, 8, 10, 10, 12, 12, 15],
      ExerciseType.integral: [6, 8, 10, 12, 12, 14, 16, 16, 18, 20],
    };
    for (final type in ExerciseType.values) {
      expect(
        [
          for (var t = 0; t < 10; t++)
            fluentTimeMs(type, Level.whole(10 * t + 5)),
        ],
        [for (final s in spec[type]!) s * 1000],
        reason: type.name,
      );
    }
  });

  test('the tier of the level decides: 39.99 is T3, 40 is T4, 100 is T9', () {
    expect(
      fluentTimeMs(ExerciseType.multiplication, Level.fromHundredths(3999)),
      7000,
    );
    expect(fluentTimeMs(ExerciseType.multiplication, Level.whole(40)), 8000);
    expect(fluentTimeMs(ExerciseType.multiplication, Level.whole(100)), 18000);
  });

  test(
    "a game's answers are credited against its frozen tier's fluent time",
    () {
      // Level 55 in addition: T5, fluent 8 s. 7.9 s is fluent; 8.1 s is not.
      AnswerResult answer(int ms) => AnswerResult(
        exercise: ArithmeticExercise(
          operandA: 347,
          operandB: 58,
          operationType: OperationType.addition,
        ),
        submittedValue: 405,
        isCorrect: true,
        elapsedMs: ms,
        answeredAt: DateTime.utc(2026, 11, 23),
      );
      Level after(int ms) => gameLevelUpdates(
        outcomes: List.generate(4, (_) => answer(ms)),
        frozenLevels: {ExerciseType.addition: Level.whole(55)},
        priorLevels: const {},
        now: DateTime.utc(2026, 11, 23),
        rulesVersion: RulesVersion.v3,
      )[ExerciseType.addition]!.level;
      expect(after(7900), Level.whole(58)); // +3: all fluent
      expect(after(8000), Level.whole(58)); // the fluent time itself counts
      expect(after(8100), Level.fromHundredths(5656)); // +1.56: all slow
    },
  );
}
