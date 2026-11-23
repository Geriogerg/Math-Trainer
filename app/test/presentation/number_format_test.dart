import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/presentation/number_format.dart';

void main() {
  test('digits grouped by three with a space, from the right', () {
    expect(groupedNumber(0), '0');
    expect(groupedNumber(999), '999');
    expect(groupedNumber(1000), '1 000');
    expect(groupedNumber(12500), '12 500');
    expect(groupedNumber(1234567890), '1 234 567 890');
    expect(groupedNumber(-4500), '−4 500');
    expect(groupedDigits('12345'), '12 345');
    expect(groupedDigits(''), '');
  });
}
