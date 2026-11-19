import 'dart:math';

import 'package:math_core/generation/composite_exercise_generator.dart';
import 'package:math_core/generation/debt_aware_type_selection_strategy.dart';
import 'package:math_core/generation/type_selection_strategy.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

class _FixedSequenceStrategy implements TypeSelectionStrategy {
  _FixedSequenceStrategy(this._sequence);
  final List<ExerciseType> _sequence;

  @override
  List<ExerciseType> sequenceFor(List<ExerciseType> sortedEnabledTypes) =>
      _sequence;
}

void main() {
  group('CompositeExerciseGenerator', () {
    test('the same seed and config always produce the same sequence', () {
      final randomA = Random(7);
      final randomB = Random(7);
      final generatorA = CompositeExerciseGenerator(
        enabledTypes: {
          ExerciseType.addition,
          ExerciseType.power,
          ExerciseType.squareRoot,
        },
      );
      final generatorB = CompositeExerciseGenerator(
        enabledTypes: {
          ExerciseType.addition,
          ExerciseType.power,
          ExerciseType.squareRoot,
        },
      );

      final sequenceA = List.generate(30, (_) => generatorA.next(randomA));
      final sequenceB = List.generate(30, (_) => generatorB.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('two Sets with the same elements inserted in a different order '
        'produce the same sequence', () {
      final randomA = Random(3);
      final randomB = Random(3);
      final generatorInsertedOneOrder = CompositeExerciseGenerator(
        enabledTypes: {
          ExerciseType.division,
          ExerciseType.percentage,
          ExerciseType.power,
        },
      );
      final generatorInsertedOtherOrder = CompositeExerciseGenerator(
        enabledTypes: {
          ExerciseType.power,
          ExerciseType.division,
          ExerciseType.percentage,
        },
      );

      final sequenceA = List.generate(
        30,
        (_) => generatorInsertedOneOrder.next(randomA),
      );
      final sequenceB = List.generate(
        30,
        (_) => generatorInsertedOtherOrder.next(randomB),
      );

      expect(sequenceA, equals(sequenceB));
    });

    test('only generates exercises of the enabled types', () {
      final generator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.subtraction, ExerciseType.squareRoot},
      );
      final random = Random(5);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(
          exercise.type,
          anyOf(ExerciseType.subtraction, ExerciseType.squareRoot),
        );
      }
    });

    test('a single enabled type produces a single-type session', () {
      final generator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.percentage},
      );
      final random = Random(9);

      for (var i = 0; i < 20; i++) {
        expect(generator.next(random).type, ExerciseType.percentage);
      }
    });

    test('rejects an empty set of types', () {
      expect(
        () => CompositeExerciseGenerator(enabledTypes: {}),
        throwsArgumentError,
      );
    });

    test('a higher level produces larger operands', () {
      final random = Random(11);
      final lowLevelGenerator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        levels: {ExerciseType.addition: Level.whole(1)},
      );
      final highLevelGenerator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        levels: {ExerciseType.addition: Level.whole(100)},
      );

      final lowLevelMax =
          List.generate(30, (_) => lowLevelGenerator.next(random))
              .cast<ArithmeticExercise>()
              .map((exercise) => exercise.operandA)
              .reduce((a, b) => a > b ? a : b);
      final highLevelMax =
          List.generate(30, (_) => highLevelGenerator.next(random))
              .cast<ArithmeticExercise>()
              .map((exercise) => exercise.operandA)
              .reduce((a, b) => a > b ? a : b);

      expect(highLevelMax, greaterThan(lowLevelMax));
    });

    test('generation reads the whole part of a level: 37.99 generates like '
        '37.00, 38.00 does not', () {
      List<Exercise> sequence(int hundredths) {
        final generator = CompositeExerciseGenerator(
          enabledTypes: {ExerciseType.multiplication, ExerciseType.power},
          levels: {
            ExerciseType.multiplication: Level.fromHundredths(hundredths),
            ExerciseType.power: Level.fromHundredths(hundredths),
          },
        );
        final random = Random(29);
        return List.generate(40, (_) => generator.next(random));
      }

      expect(sequence(3799), sequence(3700));
      expect(sequence(3800), isNot(sequence(3700)));
    });

    test('an enabled type missing from levels uses the level 50 fallback', () {
      final withoutLevel = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
      );
      final withLevel50 = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        levels: {ExerciseType.addition: Level.whole(50)},
      );

      final randomA = Random(13);
      final randomB = Random(13);
      final sequenceA = List.generate(20, (_) => withoutLevel.next(randomA));
      final sequenceB = List.generate(20, (_) => withLevel50.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test(
      'with a strategy, the type sequence follows exactly what it returns',
      () {
        final strategy = _FixedSequenceStrategy([
          ExerciseType.subtraction,
          ExerciseType.addition,
          ExerciseType.subtraction,
        ]);
        final generator = CompositeExerciseGenerator(
          enabledTypes: {ExerciseType.addition, ExerciseType.subtraction},
          strategy: strategy,
        );
        final random = Random(1);

        final types = List.generate(3, (_) => generator.next(random).type);

        expect(types, [
          ExerciseType.subtraction,
          ExerciseType.addition,
          ExerciseType.subtraction,
        ]);
      },
    );

    test('with a strategy, a call beyond the sequence throws', () {
      final strategy = _FixedSequenceStrategy([ExerciseType.addition]);
      final generator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        strategy: strategy,
      );
      final random = Random(1);

      generator.next(random);

      expect(() => generator.next(random), throwsStateError);
    });

    test(
      'with DebtAwareTypeSelectionStrategy, the same seed and debt produce the same '
      'full sequence (values included)',
      () {
        Map<ExerciseType, int> sessionsPlayedByType() => {
          ExerciseType.addition: 3,
          ExerciseType.subtraction: 0,
        };

        final generatorA = CompositeExerciseGenerator(
          enabledTypes: {ExerciseType.addition, ExerciseType.subtraction},
          levels: {
            ExerciseType.addition: Level.whole(40),
            ExerciseType.subtraction: Level.whole(60),
          },
          strategy: DebtAwareTypeSelectionStrategy(
            exerciseCount: 16,
            nMin: 8,
            sessionsPlayedByType: sessionsPlayedByType(),
          ),
        );
        final generatorB = CompositeExerciseGenerator(
          enabledTypes: {ExerciseType.addition, ExerciseType.subtraction},
          levels: {
            ExerciseType.addition: Level.whole(40),
            ExerciseType.subtraction: Level.whole(60),
          },
          strategy: DebtAwareTypeSelectionStrategy(
            exerciseCount: 16,
            nMin: 8,
            sessionsPlayedByType: sessionsPlayedByType(),
          ),
        );

        final randomA = Random(21);
        final randomB = Random(21);
        final sequenceA = List.generate(16, (_) => generatorA.next(randomA));
        final sequenceB = List.generate(16, (_) => generatorB.next(randomB));

        expect(sequenceA, equals(sequenceB));
      },
    );
  });
}
