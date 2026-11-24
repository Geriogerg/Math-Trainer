import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';

/// Something tracked per player by the weak-spot scheduler (plan v3.5,
/// Phase 4): a [FactItem] — a small question worth knowing by heart, asked
/// again exactly — or a [SkillItem] — a shortcut, asked again with new
/// numbers. Every item belongs to one operation ([type]): an item is
/// re-asked only at a tier of that operation (`doc/decisions.md`, "Phase
/// 4").
///
/// [key] is stored (sessions' `weakSpots`, uploads) and parsed back by
/// [Item.parse]: never change its format, an `ExerciseType` or a
/// `PatternFamily` name.
sealed class Item implements Comparable<Item> {
  const Item();

  ExerciseType get type;

  /// `fact:multiplication:7,8`, `skill:differenceOfSquares`.
  String get key;

  /// Throws [FormatException] for a string no item has (an upload is bad
  /// input, never guessed).
  static Item parse(String key) {
    final parts = key.split(':');
    switch (parts) {
      case ['skill', final name]:
        for (final family in PatternFamily.values) {
          if (family.name == name) return SkillItem(family);
        }
      case ['fact', final typeName, final numbers]:
        final type = _typeNamed(typeName);
        final values = numbers.split(',').map(int.tryParse).toList();
        if (type != null && values.isNotEmpty && !values.contains(null)) {
          try {
            return FactItem(type, [for (final v in values) v!]);
          } on ArgumentError {
            // Not a fact: below.
          }
        }
    }
    throw FormatException('not an item key: $key');
  }

  /// By key: a stable order for ties (never a `Set`'s, rule 2).
  @override
  int compareTo(Item other) => key.compareTo(other.key);

  @override
  bool operator ==(Object other) => other is Item && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// A fact in its canonical form (`doc/decisions.md`, "Phase 4"): [numbers]
/// are, by operation —
/// addition `[smaller, larger]` (commutative: one entry), subtraction
/// `[minuend, subtrahend]`, multiplication `[smaller, larger]`, division
/// `[dividend, divisor]`, power `[base, exponent]`, root `[index,
/// radicand]`, percentage `[percent, base]`. Built only through
/// `factOf` or [Item.parse], which check it is one of the catalogue's.
final class FactItem extends Item {
  /// Throws unless [numbers] is a canonical fact of [type] (rule 13).
  FactItem(this.type, List<int> numbers)
    : numbers = List.unmodifiable(numbers) {
    if (!isCanonicalFact(type, this.numbers)) {
      throw ArgumentError.value(numbers, 'numbers', 'not a ${type.name} fact.');
    }
  }

  @override
  final ExerciseType type;

  final List<int> numbers;

  @override
  String get key => 'fact:${type.name}:${numbers.join(',')}';
}

/// A pattern family as a skill (plan v3.5: "the pattern families and Method
/// strategies"; a strategy counts as its family, `skillFamilyOf`).
final class SkillItem extends Item {
  const SkillItem(this.family);

  final PatternFamily family;

  @override
  ExerciseType get type => family.type;

  @override
  String get key => 'skill:${family.name}';
}

ExerciseType? _typeNamed(String name) {
  for (final type in ExerciseType.values) {
    if (type.name == name) return type;
  }
  return null;
}

/// The catalogue's facts (plan v3.5, "Facts"), as canonical numbers:
/// addition bonds within 20 and complements to 100, their subtractions;
/// tables up to 20 × 20 and their divisions; squares to 30², cubes to 10³,
/// 2¹–2¹², their roots; 10, 20, 25, 50, 75 % of round numbers.
bool isCanonicalFact(ExerciseType type, List<int> n) => switch (type) {
  ExerciseType.addition => switch (n) {
    [final a, final b] => a >= 1 && a <= b && (a + b <= 20 || a + b == 100),
    _ => false,
  },
  ExerciseType.subtraction => switch (n) {
    [final s, final a] => a >= 1 && s - a >= 1 && (s <= 20 || s == 100),
    _ => false,
  },
  ExerciseType.multiplication => switch (n) {
    [final a, final b] => a >= 1 && a <= b && b <= 20,
    _ => false,
  },
  ExerciseType.division => switch (n) {
    [final dividend, final divisor] =>
      divisor >= 1 &&
          divisor <= 20 &&
          dividend % divisor == 0 &&
          dividend ~/ divisor >= 1 &&
          dividend ~/ divisor <= 20,
    _ => false,
  },
  ExerciseType.power => switch (n) {
    [final base, final exponent] => _isFactPower(base, exponent),
    _ => false,
  },
  ExerciseType.squareRoot => switch (n) {
    [2, final radicand] => _factSquareRoots.contains(_exactRoot(radicand, 2)),
    [3, final radicand] => _factCubeRoots.contains(_exactRoot(radicand, 3)),
    _ => false,
  },
  ExerciseType.percentage => switch (n) {
    [final percent, final base] =>
      friendlyFactPercents.contains(percent) &&
          base >= 10 &&
          base <= 1000 &&
          base % 10 == 0 &&
          percent * base % 100 == 0,
    _ => false,
  },
  ExerciseType.integral => false,
};

/// The percentages a fact may have.
const friendlyFactPercents = [10, 20, 25, 50, 75];

bool _isFactPower(int base, int exponent) =>
    (exponent == 2 && base >= 1 && base <= 30) ||
    (exponent == 3 && base >= 1 && base <= 10) ||
    (base == 2 && exponent >= 1 && exponent <= 12);

/// √ of the squares 1²–30² and of 2², 2⁴ … 2¹²: roots 1–30, 32 and 64.
final _factSquareRoots = {for (var r = 1; r <= 30; r++) r, 32, 64};

/// ∛ of the cubes 1³–10³.
final _factCubeRoots = {for (var r = 1; r <= 10; r++) r};

int? _exactRoot(int radicand, int index) =>
    index == 2 ? _squareRootOf(radicand) : _cubeRootOf(radicand);

/// Integer search, never a floating-point sqrt (pitfall).
int? _squareRootOf(int n) {
  if (n < 1) return null;
  var r = 0;
  while ((r + 1) * (r + 1) <= n) {
    r++;
  }
  return r * r == n ? r : null;
}

int? _cubeRootOf(int n) {
  if (n < 1) return null;
  var r = 0;
  while ((r + 1) * (r + 1) * (r + 1) <= n) {
    r++;
  }
  return r * r * r == n ? r : null;
}
