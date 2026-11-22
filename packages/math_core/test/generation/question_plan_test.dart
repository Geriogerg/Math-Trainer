import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

void main() {
  const add = ExerciseType.addition;
  const mul = ExerciseType.multiplication;

  test('each operation gets exactly the chosen count', () {
    for (final perOperation in questionsPerOperationChoices) {
      final sequence = shuffledTypeSequence(
        types: {mul, add},
        perOperation: perOperation,
        seed: 7,
      );
      expect(sequence.length, 2 * perOperation);
      expect(sequence.where((t) => t == add).length, perOperation);
      expect(sequence.where((t) => t == mul).length, perOperation);
    }
  });

  test('every choice reaches n_min (4)', () {
    expect(questionsPerOperationChoices.every((n) => n >= 4), isTrue);
    expect(
      questionsPerOperationChoices,
      contains(defaultQuestionsPerOperation),
    );
  });

  test('same seed, same order — whatever the set insertion order', () {
    final a = shuffledTypeSequence(types: {add, mul}, perOperation: 5, seed: 3);
    final b = shuffledTypeSequence(types: {mul, add}, perOperation: 5, seed: 3);
    expect(a, b);
  });

  test('pinned on VM and JavaScript', () {
    // A change here reorders every new game of a given seed.
    expect(
      shuffledTypeSequence(types: {add, mul}, perOperation: 4, seed: 42),
      _pinned,
    );
  });

  test('the order is shuffled, not blocked by type', () {
    final sequence = shuffledTypeSequence(
      types: {add, mul},
      perOperation: 10,
      seed: 1,
    );
    expect(sequence.take(10).toSet(), {add, mul});
  });

  test('invalid input throws', () {
    expect(
      () => shuffledTypeSequence(types: {}, perOperation: 4, seed: 1),
      throwsArgumentError,
    );
    expect(
      () => shuffledTypeSequence(types: {add}, perOperation: 0, seed: 1),
      throwsArgumentError,
    );
  });
}

const _pinned = [
  ExerciseType.multiplication,
  ExerciseType.multiplication,
  ExerciseType.addition,
  ExerciseType.multiplication,
  ExerciseType.multiplication,
  ExerciseType.addition,
  ExerciseType.addition,
  ExerciseType.addition,
];
