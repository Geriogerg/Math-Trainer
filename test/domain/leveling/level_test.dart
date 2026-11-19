import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:test/test.dart';

void main() {
  group('Level', () {
    test('keeps hundredths; whole part truncates, value is the fraction', () {
      final level = Level.fromHundredths(3799);
      expect(level.hundredths, 3799);
      expect(level.whole, 37); // truncated: the displayed level is the one
      // that sets the difficulty
      expect(level.value, 37.99);
    });

    test('whole levels are multiples of 100', () {
      expect(Level.whole(1).hundredths, 100);
      expect(Level.whole(37).hundredths, 3700);
      expect(Level.whole(100).hundredths, 10000);
      expect(Level.whole(37).whole, 37);
    });

    test('floor is 1.00', () {
      expect(Level.floor.hundredths, 100);
      expect(Level.floor, Level.whole(1));
    });

    test('rejects hundredths outside [100, 10000]', () {
      expect(() => Level.fromHundredths(99), throwsArgumentError);
      expect(() => Level.fromHundredths(10001), throwsArgumentError);
      expect(() => Level.fromHundredths(0), throwsArgumentError);
    });

    test('rejects a whole level outside [1, 100]', () {
      expect(() => Level.whole(0), throwsArgumentError);
      expect(() => Level.whole(101), throwsArgumentError);
    });

    test('clamped brings any value into range, never throws', () {
      expect(Level.clamped(-500).hundredths, 100);
      expect(Level.clamped(99).hundredths, 100);
      expect(Level.clamped(4242).hundredths, 4242);
      expect(Level.clamped(10301).hundredths, 10000);
    });

    test('equality is by value (stored and compared as an int)', () {
      expect(Level.fromHundredths(4242), Level.fromHundredths(4242));
      expect(
        Level.fromHundredths(4242).hashCode,
        Level.fromHundredths(4242).hashCode,
      );
      expect(Level.fromHundredths(4242) == Level.fromHundredths(4243), isFalse);
    });
  });
}
