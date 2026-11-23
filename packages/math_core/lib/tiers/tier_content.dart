import 'dart:math';

import '../models/exercise.dart';
import '../models/exercise_type.dart';
import 'arithmetic_tiers.dart';
import 'integral_tiers.dart';
import 'percentage_tiers.dart';
import 'power_tiers.dart';
import 'tier.dart';

/// One question of [type] at [tier] (`doc/levels.md`, section 5), drawn
/// from [random] — the content of every tier of every operation, in one
/// place. Rules v2's only generator.
Exercise exerciseAt(ExerciseType type, Tier tier, Random random) =>
    switch (type) {
      ExerciseType.addition ||
      ExerciseType.subtraction ||
      ExerciseType.multiplication ||
      ExerciseType.division => arithmeticAt(type.operationType!, tier, random),
      ExerciseType.power => powerAt(tier, random),
      ExerciseType.squareRoot => rootAt(tier, random),
      ExerciseType.percentage => percentageAt(tier, random),
      ExerciseType.integral => integralAt(tier, random),
    };
