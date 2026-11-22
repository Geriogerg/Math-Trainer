import 'package:math_core/leveling/rules_version.dart';
import 'package:test/test.dart';

void main() {
  test('stored numbers never move; an unknown number throws (rule 13)', () {
    expect(RulesVersion.v1.number, 1);
    expect(RulesVersion.v2.number, 2);
    expect(RulesVersion.of(1), RulesVersion.v1);
    expect(RulesVersion.of(2), RulesVersion.v2);
    expect(() => RulesVersion.of(0), throwsArgumentError);
    expect(() => RulesVersion.of(3), throwsArgumentError);
  });
}
