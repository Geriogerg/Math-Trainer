import 'dart:math';

import '../difficulty/arithmetic_difficulty.dart';
import '../difficulty/percentage_difficulty.dart';
import '../difficulty/power_difficulty.dart';
import '../difficulty/square_root_difficulty.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import 'arithmetic_generator.dart';
import 'exercise_generator.dart';
import 'percentage_generator.dart';
import 'power_generator.dart';
import 'square_root_generator.dart';

/// Niveau utilisé pour tout type activé absent de `levels` — repli
/// temporaire tant que le commit D ne câble pas les vrais niveaux depuis
/// l'historique (voir `doc/decisions.md`, étape 4 commit C).
const _defaultLevel = 50;

/// Un seul flux seedé pour toutes les familles activées : le tirage « quel
/// type ? » et les tirages « quelles valeurs ? » qui suivent partagent le
/// même [Random]. `enabledTypes` est converti une fois en liste triée par
/// `.index` au constructeur — ne jamais tirer directement sur un `Set`,
/// dont l'ordre d'itération suit l'insertion, pas le contenu : deux `Set`
/// avec les mêmes éléments dans un ordre différent casseraient sinon la
/// règle 2 (même config → même séquence) sans erreur visible.
class CompositeExerciseGenerator implements ExerciseGenerator {
  CompositeExerciseGenerator({required Set<ExerciseType> enabledTypes, Map<ExerciseType, int>? levels})
    : _sortedTypes = enabledTypes.toList()..sort((a, b) => a.index.compareTo(b.index)),
      _generators = {
        for (final type in enabledTypes)
          type: _buildGenerator(type, levels?[type] ?? _defaultLevel),
      } {
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

  static ExerciseGenerator _buildGenerator(ExerciseType type, int level) => switch (type) {
    ExerciseType.addition => ArithmeticExerciseGenerator(
      operationTypes: [type.operationType!],
      operandRange: additionDifficulty.operandRangeFor(level),
    ),
    ExerciseType.subtraction => ArithmeticExerciseGenerator(
      operationTypes: [type.operationType!],
      operandRange: subtractionDifficulty.operandRangeFor(level),
    ),
    ExerciseType.multiplication => ArithmeticExerciseGenerator(
      operationTypes: [type.operationType!],
      operandRange: multiplicationDifficulty.operandRangeFor(level),
    ),
    ExerciseType.division => ArithmeticExerciseGenerator(
      operationTypes: [type.operationType!],
      operandRange: divisionDifficulty.operandRangeFor(level),
    ),
    ExerciseType.power => PowerExerciseGenerator(
      exponentRange: powerDifficulty.exponentRangeFor(level),
    ),
    ExerciseType.squareRoot => SquareRootExerciseGenerator(
      rootRange: squareRootDifficulty.rootRangeFor(level),
    ),
    ExerciseType.percentage => PercentageExerciseGenerator(
      percentRange: percentageDifficulty.percentRangeFor(level),
    ),
  };
}
