import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  test('stored names never change', () {
    expect(
      [for (final m in DuelMode.values) m.name],
      ['basics', 'advanced', 'count'],
    );
    expect([for (final v in DuelRulesVersion.values) v.number], [1]);
  });

  test('question modes draw two of each of their family', () {
    expect(DuelMode.basics.types, [
      ExerciseType.addition,
      ExerciseType.subtraction,
      ExerciseType.multiplication,
      ExerciseType.division,
    ]);
    expect(DuelMode.advanced.types, [
      ExerciseType.power,
      ExerciseType.squareRoot,
      ExerciseType.percentage,
      ExerciseType.integral,
    ]);
    expect(DuelMode.count.types, isEmpty);
    expect(DuelMode.count.isQuiz, isFalse);
  });

  test('parsing is strict', () {
    expect(DuelMode.parse('count'), DuelMode.count);
    expect(() => DuelMode.parse('chain'), throwsFormatException);
    expect(() => DuelMode.parse(null), throwsFormatException);
    expect(DuelRulesVersion.of(1), DuelRulesVersion.v1);
    expect(() => DuelRulesVersion.of(2), throwsFormatException);
    expect(() => DuelRulesVersion.of('1'), throwsFormatException);
  });
}
