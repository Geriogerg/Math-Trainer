import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tip_band.dart';
import 'package:test/test.dart';

void main() {
  test('beginner T0–T2, intermediate T3–T5, advanced T6–T9', () {
    expect(
      [for (final t in Tier.values) TipBand.of(t)],
      [
        for (var i = 0; i < 3; i++) TipBand.beginner,
        for (var i = 0; i < 3; i++) TipBand.intermediate,
        for (var i = 0; i < 4; i++) TipBand.advanced,
      ],
    );
  });
}
