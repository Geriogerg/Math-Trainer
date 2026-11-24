import 'dart:math';

import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
import '../patterns/pattern_questions.dart';
import '../patterns/pattern_questions_v4.dart';
import 'arithmetic_tiers.dart';
import 'draw.dart';
import 'integral_tiers.dart';
import 'long_arithmetic_tiers.dart';
import 'percentage_tiers.dart';
import 'power_tiers.dart';
import 'tier.dart';

/// One question of [type] at [tier] under rules v2 and v3, drawn from
/// [random]: `doc/levels.md` section 5, except addition and subtraction
/// ([arithmeticAt]'s earlier, shorter tables). Frozen: their games replay
/// with it — a change here is a new rules version.
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

/// A question as drawn, with the pattern family it came from (`null`: a
/// standard question of the tier).
typedef TierQuestion = ({Exercise exercise, PatternFamily? family});

/// What a game generator draws one question with: [type] at [tier].
typedef TierContent =
    TierQuestion Function(ExerciseType type, Tier tier, Random random);

/// Rules v2 and v3: [exerciseAt], never a pattern question.
TierQuestion standardContent(ExerciseType type, Tier tier, Random random) =>
    (exercise: exerciseAt(type, tier, random), family: null);

/// How often a question is a pattern question where a family is available
/// (`doc/levels.md` section 5b: about 40 %, tunable): 2 in 5.
const patternShareFifths = 2;

/// Rules v4 (`doc/levels.md` v1.2 sections 5 and 5b): at a tier where at
/// least one family of [type] is available, a pattern question 2 times in
/// 5, its family drawn uniformly among them; otherwise the tier's standard
/// question — addition and subtraction from the spec's long tables
/// ([longArithmeticAt]), the other six as under v2. Nothing is drawn for
/// the share where no family is available (T0). Its pattern questions have
/// one size for every tier ([patternQuestionV4]). Frozen: v4 games replay
/// with it.
TierQuestion patternedContent(ExerciseType type, Tier tier, Random random) {
  final families = PatternFamily.availableAtV4(type, tier);
  if (families.isNotEmpty && random.nextInt(5) < patternShareFifths) {
    final family = drawOne(random, families);
    return (exercise: patternQuestionV4(family, random), family: family);
  }
  return (exercise: _standardV4(type, tier, random), family: null);
}

/// Rules v5 (`doc/levels.md` v1.4 sections 5 and 5b): v4's mix and
/// standard questions, with pattern questions **sized by tier**
/// ([patternQuestionV5]) and the families available as spec v1.4 lists them.
/// Frozen: v5 games replay with it.
TierQuestion patternedContentV5(ExerciseType type, Tier tier, Random random) {
  final families = PatternFamily.availableAt(type, tier);
  if (families.isNotEmpty && random.nextInt(5) < patternShareFifths) {
    final family = drawOne(random, families);
    return (exercise: patternQuestionV5(family, tier, random), family: family);
  }
  return (exercise: _standardV4(type, tier, random), family: null);
}

/// Rules v6 (`doc/levels.md` v1.5): v5's, with √ of powers of 2 sized by
/// its own row ([patternQuestion]).
TierQuestion patternedContentV6(ExerciseType type, Tier tier, Random random) {
  final families = PatternFamily.availableAt(type, tier);
  if (families.isNotEmpty && random.nextInt(5) < patternShareFifths) {
    final family = drawOne(random, families);
    return (exercise: patternQuestion(family, tier, random), family: family);
  }
  return (exercise: _standardV4(type, tier, random), family: null);
}

Exercise _standardV4(ExerciseType type, Tier tier, Random random) =>
    switch (type) {
      ExerciseType.addition || ExerciseType.subtraction => longArithmeticAt(
        type.operationType!,
        tier,
        random,
      ),
      ExerciseType.multiplication ||
      ExerciseType.division ||
      ExerciseType.power ||
      ExerciseType.squareRoot ||
      ExerciseType.percentage ||
      ExerciseType.integral => exerciseAt(type, tier, random),
    };
