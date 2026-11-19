import 'dart:math';

import '../difficulty/arithmetic_difficulty.dart';
import '../difficulty/percentage_difficulty.dart';
import '../difficulty/power_difficulty.dart';
import '../difficulty/square_root_difficulty.dart';
import '../leveling/level.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import 'arithmetic_generator.dart';
import 'exercise_generator.dart';
import 'percentage_generator.dart';
import 'power_generator.dart';
import 'square_root_generator.dart';
import 'type_selection_strategy.dart';

/// Level used for any enabled type missing from `levels` — a temporary
/// fallback until commit D wires the real levels from history (see
/// `doc/decisions.md`, step 4 commit C).
const _defaultLevel = 50;

/// One seeded stream for every enabled family: the "which type?" draw and
/// the "which values?" draws that follow share the same [Random].
/// `enabledTypes` is converted once into a list sorted by `.index` in the
/// constructor — never draw directly from a `Set`, whose iteration order
/// follows insertion, not content: two `Set`s with the same elements in a
/// different order would otherwise break rule 2 (same config → same
/// sequence) with no visible error.
class CompositeExerciseGenerator implements ExerciseGenerator {
  CompositeExerciseGenerator({
    required Set<ExerciseType> enabledTypes,
    Map<ExerciseType, Level>? levels,
    TypeSelectionStrategy? strategy,
  }) : _sortedTypes = enabledTypes.toList()
         ..sort((a, b) => a.index.compareTo(b.index)),
       _generators = {
         for (final type in enabledTypes)
           // Generation reads the whole part of a level (plan, Phase 1
           // commit 2): 37.99 generates exactly like 37.00, so sequences
           // from before continuous levels replay unchanged.
           type: _buildGenerator(type, levels?[type]?.whole ?? _defaultLevel),
       } {
    if (enabledTypes.isEmpty) {
      throw ArgumentError.value(
        enabledTypes,
        'enabledTypes',
        'must not be empty.',
      );
    }
    _sequence = strategy?.sequenceFor(_sortedTypes);
  }

  final List<ExerciseType> _sortedTypes;
  final Map<ExerciseType, ExerciseGenerator> _generators;

  /// `null`: endless stream, one uniform draw per call (historical
  /// behaviour, unchanged). Non-`null`: bounded sequence built once by the
  /// injected strategy — see `doc/decisions.md`.
  List<ExerciseType>? _sequence;
  int _position = 0;

  @override
  Exercise next(Random random) {
    final ExerciseType type;
    final sequence = _sequence;
    if (sequence != null) {
      if (_position >= sequence.length) {
        throw StateError(
          'Sequence exhausted ($_position/${sequence.length}) — the strategy was built '
          'for a fixed number of questions.',
        );
      }
      type = sequence[_position++];
    } else {
      type = _sortedTypes[random.nextInt(_sortedTypes.length)];
    }
    return _generators[type]!.next(random);
  }

  static ExerciseGenerator _buildGenerator(ExerciseType type, int level) =>
      switch (type) {
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
