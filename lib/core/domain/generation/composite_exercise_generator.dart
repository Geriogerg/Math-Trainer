import 'dart:math';

import '../models/exercise.dart';
import '../models/exercise_type.dart';
import 'arithmetic_generator.dart';
import 'exercise_generator.dart';
import 'percentage_generator.dart';
import 'power_generator.dart';
import 'square_root_generator.dart';

/// Un seul flux seedé pour toutes les familles activées : le tirage « quel
/// type ? » et les tirages « quelles valeurs ? » qui suivent partagent le
/// même [Random]. `enabledTypes` est converti une fois en liste triée par
/// `.index` au constructeur — ne jamais tirer directement sur un `Set`,
/// dont l'ordre d'itération suit l'insertion, pas le contenu : deux `Set`
/// avec les mêmes éléments dans un ordre différent casseraient sinon la
/// règle 2 (même config → même séquence) sans erreur visible.
class CompositeExerciseGenerator implements ExerciseGenerator {
  CompositeExerciseGenerator({required Set<ExerciseType> enabledTypes})
    : _sortedTypes = enabledTypes.toList()..sort((a, b) => a.index.compareTo(b.index)),
      _generators = {for (final type in enabledTypes) type: _buildGenerator(type)} {
    if (enabledTypes.isEmpty) {
      throw ArgumentError.value(enabledTypes, 'enabledTypes', 'ne doit pas être vide.');
    }
  }

  final List<ExerciseType> _sortedTypes;
  final Map<ExerciseType, ExerciseGenerator> _generators;

  @override
  Exercise next(Random random) {
    final type = _sortedTypes[random.nextInt(_sortedTypes.length)];
    return _generators[type]!.next(random);
  }

  static ExerciseGenerator _buildGenerator(ExerciseType type) => switch (type) {
    ExerciseType.addition ||
    ExerciseType.subtraction ||
    ExerciseType.multiplication ||
    ExerciseType.division => ArithmeticExerciseGenerator(operationTypes: [type.operationType!]),
    ExerciseType.power => const PowerExerciseGenerator(),
    ExerciseType.squareRoot => const SquareRootExerciseGenerator(),
    ExerciseType.percentage => const PercentageExerciseGenerator(),
  };
}
