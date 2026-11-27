import 'package:math_core/models/operation_type.dart';

/// What a screen reader says for a prompt's parts (Phase 6b commit 6,
/// review M17; in two languages since Phase 6d): words for the signs,
/// numbers ungrouped — "4 789" would be read as two numbers.
/// `spoken_prompt.dart` assembles them.
abstract interface class SpokenStrings {
  /// An arithmetic sign between two numbers: "plus", "divided by".
  String operator(OperationType type);

  /// "12 squared", "2 to the power 5".
  String power(int base, int exponent);

  /// "the square root of 169", "the cube root of 27".
  String root(int index, int radicand);

  /// "37.5 percent of 64".
  String percent(int whole, int tenths, int base);

  /// "the integral from 0 to 3 of [polynomial], d x".
  String integral(int lower, int upper, String polynomial);

  /// Between two terms of a polynomial: " plus " or " minus ".
  String sign({required bool negative});

  /// The x of a term of degree [power]: "", "x", "x squared"…
  String xPower(int power);
}

/// SpokenStrings in English.
class EnglishSpokenStrings implements SpokenStrings {
  const EnglishSpokenStrings();

  @override
  String operator(OperationType type) => switch (type) {
    OperationType.addition => 'plus',
    OperationType.subtraction => 'minus',
    OperationType.multiplication => 'times',
    OperationType.division => 'divided by',
  };

  @override
  String power(int base, int exponent) => switch (exponent) {
    2 => '$base squared',
    3 => '$base cubed',
    final n => '$base to the power $n',
  };

  @override
  String root(int index, int radicand) => switch (index) {
    2 => 'the square root of $radicand',
    3 => 'the cube root of $radicand',
    final n => 'the root $n of $radicand',
  };

  @override
  String percent(int whole, int tenths, int base) =>
      '$whole${tenths == 0 ? '' : '.$tenths'} percent of $base';

  @override
  String integral(int lower, int upper, String polynomial) =>
      'the integral from $lower to $upper of $polynomial, d x';

  @override
  String sign({required bool negative}) => negative ? ' minus ' : ' plus ';

  @override
  String xPower(int power) => switch (power) {
    0 => '',
    1 => 'x',
    2 => 'x squared',
    3 => 'x cubed',
    final n => 'x to the power $n',
  };
}
