import 'package:math_core/models/input_device.dart';
import 'package:test/test.dart';

void main() {
  test('one device stays itself, two make mixed', () {
    expect(InputDevice.combine(null, InputDevice.keypad), InputDevice.keypad);
    expect(
      InputDevice.combine(InputDevice.keyboard, InputDevice.keyboard),
      InputDevice.keyboard,
    );
    expect(
      InputDevice.combine(InputDevice.keypad, InputDevice.keyboard),
      InputDevice.mixed,
    );
    expect(
      InputDevice.combine(InputDevice.mixed, InputDevice.keypad),
      InputDevice.mixed,
    );
  });

  test('stored names never change', () {
    expect(InputDevice.values.map((d) => d.name), [
      'keypad',
      'keyboard',
      'mixed',
    ]);
  });
}
