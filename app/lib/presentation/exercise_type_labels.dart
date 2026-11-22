import 'package:math_core/models/exercise_type.dart';

String exerciseTypeLabel(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Subtraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Powers',
  ExerciseType.squareRoot => 'Square roots',
  ExerciseType.percentage => 'Percentages',
  ExerciseType.integral => 'Integrals',
};

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
