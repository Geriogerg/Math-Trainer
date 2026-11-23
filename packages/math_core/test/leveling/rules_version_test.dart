import 'package:math_core/leveling/rules_version.dart';
import 'package:test/test.dart';

void main() {
  test('stored numbers never move; an unknown number throws (rule 13)', () {
    expect(RulesVersion.v1.number, 1);
    expect(RulesVersion.v2.number, 2);
    expect(RulesVersion.v3.number, 3);
    expect(RulesVersion.v4.number, 4);
    expect(RulesVersion.of(1), RulesVersion.v1);
    expect(RulesVersion.of(2), RulesVersion.v2);
    expect(RulesVersion.of(3), RulesVersion.v3);
    expect(RulesVersion.of(4), RulesVersion.v4);
    expect(() => RulesVersion.of(0), throwsArgumentError);
    expect(() => RulesVersion.of(5), throwsArgumentError);
  });

  test('new games play v4; v2, v3 and v4 are replayed; only v1 is '
      'retired', () {
    expect(RulesVersion.current, RulesVersion.v4);
    expect(RulesVersion.replayed, [
      RulesVersion.v2,
      RulesVersion.v3,
      RulesVersion.v4,
    ]);
    expect(
      [for (final v in RulesVersion.values) v.retired],
      [true, false, false, false],
    );
  });
}
