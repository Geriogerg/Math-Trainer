import 'dart:math';

import 'package:math_trainer/core/domain/generation/composite_exercise_generator.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  group('CompositeExerciseGenerator', () {
    test('la même seed et la même config produisent toujours la même séquence', () {
      final randomA = Random(7);
      final randomB = Random(7);
      final generatorA = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition, ExerciseType.power, ExerciseType.squareRoot},
      );
      final generatorB = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition, ExerciseType.power, ExerciseType.squareRoot},
      );

      final sequenceA = List.generate(30, (_) => generatorA.next(randomA));
      final sequenceB = List.generate(30, (_) => generatorB.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });

    test('deux Set aux mêmes éléments mais insérés dans un ordre différent '
        'produisent la même séquence', () {
      final randomA = Random(3);
      final randomB = Random(3);
      final generatorInsertedOneOrder = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.division, ExerciseType.percentage, ExerciseType.power},
      );
      final generatorInsertedOtherOrder = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.power, ExerciseType.division, ExerciseType.percentage},
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

    test('ne génère que des exercices des types activés', () {
      final generator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.subtraction, ExerciseType.squareRoot},
      );
      final random = Random(5);

      for (var i = 0; i < 50; i++) {
        final exercise = generator.next(random);
        expect(exercise.type, anyOf(ExerciseType.subtraction, ExerciseType.squareRoot));
      }
    });

    test('un seul type activé produit une session mono-type', () {
      final generator = CompositeExerciseGenerator(enabledTypes: {ExerciseType.percentage});
      final random = Random(9);

      for (var i = 0; i < 20; i++) {
        expect(generator.next(random).type, ExerciseType.percentage);
      }
    });

    test('refuse un ensemble de types vide', () {
      expect(() => CompositeExerciseGenerator(enabledTypes: {}), throwsArgumentError);
    });

    test('un niveau plus élevé produit des opérandes plus grands', () {
      final random = Random(11);
      final lowLevelGenerator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        levels: {ExerciseType.addition: 1},
      );
      final highLevelGenerator = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        levels: {ExerciseType.addition: 100},
      );

      final lowLevelMax = List.generate(30, (_) => lowLevelGenerator.next(random))
          .cast<ArithmeticExercise>()
          .map((exercise) => exercise.operandA)
          .reduce((a, b) => a > b ? a : b);
      final highLevelMax = List.generate(30, (_) => highLevelGenerator.next(random))
          .cast<ArithmeticExercise>()
          .map((exercise) => exercise.operandA)
          .reduce((a, b) => a > b ? a : b);

      expect(highLevelMax, greaterThan(lowLevelMax));
    });

    test('un type activé sans entrée dans levels utilise le repli niveau 50', () {
      final withoutLevel = CompositeExerciseGenerator(enabledTypes: {ExerciseType.addition});
      final withLevel50 = CompositeExerciseGenerator(
        enabledTypes: {ExerciseType.addition},
        levels: {ExerciseType.addition: 50},
      );

      final randomA = Random(13);
      final randomB = Random(13);
      final sequenceA = List.generate(20, (_) => withoutLevel.next(randomA));
      final sequenceB = List.generate(20, (_) => withLevel50.next(randomB));

      expect(sequenceA, equals(sequenceB));
    });
  });
}
