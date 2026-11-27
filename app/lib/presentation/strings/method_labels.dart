import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';

import 'strings.dart';

/// The strategy's name a Method shows above its lines (`doc/levels.md`
/// section 9: "the name of the strategy", minimal text; v1.6: "the strategy
/// name matches what the lines do"). The domain names none: these are the
/// app's words. [type] names a fallback the core did not describe.
String methodName(Method method, ExerciseType type) {
  if (method.family case final family?) return patternFamilyLabel(family);
  if (method.strategy case final strategy?) return strategyLabel(strategy);
  if (method.fallback case final fallback?) return fallbackLabel(fallback);
  return operationFallbackLabel(type);
}

String patternFamilyLabel(PatternFamily family) =>
    strings.labels.patternFamily(family);

String strategyLabel(Strategy strategy) => strings.labels.strategy(strategy);

/// What a fallback's lines do (Phase 6b commit 3, review M11: "From the
/// nearest ten" stood above 2³, "Think of the multiplication" above a split
/// dividend).
String fallbackLabel(MethodFallback fallback) =>
    strings.labels.fallback(fallback);

/// `doc/levels.md` section 9's fallback column, by operation: a Method the
/// core built without naming its fallback.
String operationFallbackLabel(ExerciseType type) =>
    strings.labels.operationFallback(type);
