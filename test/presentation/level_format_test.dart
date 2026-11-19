import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/presentation/level_format.dart';

void main() {
  test('formatLevelChange: sign, two decimals, true minus sign', () {
    expect(formatLevelChange(42), '+0.42');
    expect(formatLevelChange(5), '+0.05');
    expect(formatLevelChange(300), '+3.00');
    expect(formatLevelChange(-105), '−1.05');
    expect(formatLevelChange(0), '±0.00');
  });
}
