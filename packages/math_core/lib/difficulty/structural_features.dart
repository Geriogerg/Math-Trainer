import '../models/exercise.dart';
import '../models/operation_type.dart';

/// What makes an exercise hard beyond its size (plan section 6.1: "47 + 38
/// is harder than 45 + 32 because of the carry"), measured per exercise for
/// **analysis only** (Phase 5.1 commit 3): Phase 3b checks which of these
/// predict slow or wrong answers. Generation never reads them — question
/// order and difficulty stay as the beta plays them.
///
/// The same rules exist in SQL (`owner_dashboard.structural_features`, the
/// view `owner_dashboard.answer_features`); `structural_features_test.dart`
/// runs the SQL test's own cases against this code, so the two cannot
/// drift. Change both or neither.
final class StructuralFeatures {
  const StructuralFeatures({
    required this.carries,
    required this.borrows,
    required this.bigDigits,
    required this.roundDistance,
  });

  /// Columns that carry in an addition (47 + 38: one); 0 for any other
  /// operation.
  final int carries;

  /// Columns that borrow in a subtraction (52 − 38: one); 0 otherwise.
  final int borrows;

  /// Digits 6 to 9 among the operands shown (7 × 46: two). A power's
  /// exponent is not counted: it is always 2 or 3, never computed with.
  final int bigDigits;

  /// The smallest distance, among the operands of 10 or more, to the
  /// nearest multiple of ten (298 → 2, 47 → 3, 45 → 5); `null` when every
  /// operand is a single digit.
  final int? roundDistance;

  @override
  bool operator ==(Object other) =>
      other is StructuralFeatures &&
      other.carries == carries &&
      other.borrows == borrows &&
      other.bigDigits == bigDigits &&
      other.roundDistance == roundDistance;

  @override
  int get hashCode => Object.hash(carries, borrows, bigDigits, roundDistance);

  @override
  String toString() =>
      'StructuralFeatures(carries: $carries, borrows: $borrows, '
      'bigDigits: $bigDigits, roundDistance: $roundDistance)';
}

/// A three-term sum (rules v4) is read on its first two addends, as the SQL
/// twin reads `operandA` and `operandB` only.
StructuralFeatures structuralFeatures(Exercise exercise) {
  final (operands, carries, borrows) = switch (exercise) {
    ArithmeticExercise(
      :final operandA,
      :final operandB,
      :final operationType,
    ) =>
      (
        [operandA, operandB],
        operationType == OperationType.addition
            ? _carries(operandA, operandB)
            : 0,
        operationType == OperationType.subtraction
            ? _borrows(operandA, operandB)
            : 0,
      ),
    PowerExercise(:final base) => ([base], 0, 0),
    SquareRootExercise(:final radicand) => ([radicand], 0, 0),
    PercentageExercise(:final percent, :final base) => ([percent, base], 0, 0),
    // The bounds: what is raised to powers. Coefficients are small.
    IntegralExercise(:final lower, :final upper) => ([lower, upper], 0, 0),
  };
  int? distance;
  for (final n in operands) {
    final value = n.abs();
    if (value < 10) continue;
    final units = value % 10;
    final d = units <= 5 ? units : 10 - units;
    if (distance == null || d < distance) distance = d;
  }
  return StructuralFeatures(
    carries: carries,
    borrows: borrows,
    bigDigits: operands.fold(0, (sum, n) => sum + _bigDigits(n.abs())),
    roundDistance: distance,
  );
}

int _bigDigits(int n) {
  var count = 0;
  do {
    if (n % 10 >= 6) count++;
    n ~/= 10;
  } while (n > 0);
  return count;
}

/// Column by column from the units, with the carry going on.
int _carries(int a, int b) {
  var count = 0;
  var carry = 0;
  a = a.abs();
  b = b.abs();
  while (a > 0 || b > 0) {
    carry = (a % 10 + b % 10 + carry) >= 10 ? 1 : 0;
    count += carry;
    a ~/= 10;
    b ~/= 10;
  }
  return count;
}

/// Column by column from the units, a borrow taking one off the next
/// column. Operands as given (the generator always makes a ≥ b).
int _borrows(int a, int b) {
  var count = 0;
  var borrow = 0;
  a = a.abs();
  b = b.abs();
  while (a > 0 || b > 0) {
    borrow = (a % 10 - borrow) < b % 10 ? 1 : 0;
    count += borrow;
    a ~/= 10;
    b ~/= 10;
  }
  return count;
}
