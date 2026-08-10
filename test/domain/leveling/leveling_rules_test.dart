import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:test/test.dart';

void main() {
  group('LevelingRules', () {
    test('refuse tRapideMs >= tLentMs', () {
      expect(() => LevelingRules(tRapideMs: 8000, tLentMs: 2000), throwsArgumentError);
      expect(() => LevelingRules(tRapideMs: 5000, tLentMs: 5000), throwsArgumentError);
    });

    test('accepte les valeurs par défaut', () {
      expect(LevelingRules().tRapideMs, lessThan(LevelingRules().tLentMs));
    });
  });
}
