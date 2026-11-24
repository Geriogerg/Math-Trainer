import 'package:math_core/leveling/rules_version.dart';
import 'package:test/test.dart';

void main() {
  test('stored numbers never move; an unknown number throws (rule 13)', () {
    expect(RulesVersion.v1.number, 1);
    expect(RulesVersion.v2.number, 2);
    expect(RulesVersion.v3.number, 3);
    expect(RulesVersion.v4.number, 4);
    expect(RulesVersion.v5.number, 5);
    expect(RulesVersion.v6.number, 6);
    expect(RulesVersion.v7.number, 7);
    expect(RulesVersion.v8.number, 8);
    expect(RulesVersion.of(1), RulesVersion.v1);
    expect(RulesVersion.of(2), RulesVersion.v2);
    expect(RulesVersion.of(3), RulesVersion.v3);
    expect(RulesVersion.of(4), RulesVersion.v4);
    expect(RulesVersion.of(5), RulesVersion.v5);
    expect(RulesVersion.of(6), RulesVersion.v6);
    expect(RulesVersion.of(7), RulesVersion.v7);
    expect(RulesVersion.of(8), RulesVersion.v8);
    expect(() => RulesVersion.of(0), throwsArgumentError);
    expect(() => RulesVersion.of(9), throwsArgumentError);
  });

  test('new games play v8; v2 to v8 are replayed; only v1 is retired', () {
    expect(RulesVersion.current, RulesVersion.v8);
    expect(RulesVersion.replayed, [
      RulesVersion.v2,
      RulesVersion.v3,
      RulesVersion.v4,
      RulesVersion.v5,
      RulesVersion.v6,
      RulesVersion.v7,
      RulesVersion.v8,
    ]);
    expect(
      [for (final v in RulesVersion.values) v.retired],
      [true, false, false, false, false, false, false, false],
    );
  });
}
