import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/leveling/rules_version.dart';
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

  // Plan v4.1, deploy-window duels.
  group('the rules an app declares for a duel', () {
    test('this build declares every version it plays, the current ones '
        'included', () {
      final declared = knownDuelRules();
      expect(declared['rules'], [
        for (final v in RulesVersion.replayed) v.number,
      ]);
      expect(declared['duelRules'], [
        for (final v in DuelRulesVersion.replayed) v.number,
      ]);
      expect(knowsCurrentDuelRules({'mode': 'basics', ...declared}), isTrue);
    });

    test('nothing declared, or the current version missing: outdated', () {
      expect(knowsCurrentDuelRules({'mode': 'basics'}), isFalse);
      expect(
        knowsCurrentDuelRules({
          'rules': [
            for (final v in RulesVersion.replayed)
              if (v != RulesVersion.current) v.number,
          ],
          'duelRules': [DuelRulesVersion.current.number],
        }),
        isFalse,
      );
      expect(
        knowsCurrentDuelRules({
          'rules': [RulesVersion.current.number],
          'duelRules': 1.0,
        }),
        isFalse,
      );
    });
  });
}
