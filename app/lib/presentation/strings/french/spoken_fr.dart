import 'package:math_core/models/operation_type.dart';

import '../spoken_strings.dart';

/// [SpokenStrings] en français (Phase 6d) : ce que dit un lecteur d'écran.
class FrenchSpokenStrings implements SpokenStrings {
  const FrenchSpokenStrings();

  @override
  String operator(OperationType type) => switch (type) {
    OperationType.addition => 'plus',
    OperationType.subtraction => 'moins',
    OperationType.multiplication => 'fois',
    OperationType.division => 'divisé par',
  };

  @override
  String power(int base, int exponent) => switch (exponent) {
    2 => '$base au carré',
    3 => '$base au cube',
    final n => '$base puissance $n',
  };

  @override
  String root(int index, int radicand) => switch (index) {
    2 => 'la racine carrée de $radicand',
    3 => 'la racine cubique de $radicand',
    final n => 'la racine $n-ième de $radicand',
  };

  @override
  String percent(int whole, int tenths, int base) =>
      '$whole${tenths == 0 ? '' : ',$tenths'} pour cent de $base';

  @override
  String integral(int lower, int upper, String polynomial) =>
      'l’intégrale de $lower à $upper de $polynomial, d x';

  @override
  String sign({required bool negative}) => negative ? ' moins ' : ' plus ';

  @override
  String xPower(int power) => switch (power) {
    0 => '',
    1 => 'x',
    2 => 'x au carré',
    3 => 'x au cube',
    final n => 'x puissance $n',
  };
}
