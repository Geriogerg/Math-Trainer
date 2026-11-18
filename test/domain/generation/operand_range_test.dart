import 'package:math_trainer/core/domain/generation/operand_range.dart';
import 'package:test/test.dart';

void main() {
  group('OperandRange', () {
    test('rejects min > max', () {
      expect(() => OperandRange(min: 10, max: 1), throwsArgumentError);
    });

    test('accepts min == max', () {
      final range = OperandRange(min: 5, max: 5);

      expect(range.min, 5);
      expect(range.max, 5);
    });
  });
}
