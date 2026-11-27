import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/presentation/number_format.dart';

void main() {
  test('digits grouped by three with a space, from the right', () {
    expect(groupedNumber(0), '0');
    expect(groupedNumber(999), '999');
    expect(groupedNumber(1000), '1\u202f000');
    expect(groupedNumber(12500), '12\u202f500');
    expect(groupedNumber(1234567890), '1\u202f234\u202f567\u202f890');
    expect(groupedNumber(-4500), '−4\u202f500');
    expect(groupedDigits('12345'), '12\u202f345');
    expect(groupedDigits(''), '');
  });
}
