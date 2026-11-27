import 'package:math_core/models/exercise_type.dart';

import 'strings.dart';

/// An operation's name, in the interface's language (`LabelStrings`).
String exerciseTypeLabel(ExerciseType type) =>
    strings.labels.exerciseType(type);

/// The operation as a symbol (Redesign phase: the setup page's title, "+ ×").
/// The true minus, times and divide signs (`doc/design.md`).
String operatorSymbol(ExerciseType type) => switch (type) {
  ExerciseType.addition => '+',
  ExerciseType.subtraction => '−',
  ExerciseType.multiplication => '×',
  ExerciseType.division => '÷',
  ExerciseType.power => 'x²',
  ExerciseType.squareRoot => '√',
  ExerciseType.percentage => '%',
  ExerciseType.integral => '∫',
};
