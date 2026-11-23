import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

import 'tier_cases.dart';
import 'tier_references.dart';

/// Rules v2's questions are the same on the VM and in JavaScript (rule 18):
/// the references were written on the VM (`tool/tier_references.dart`);
/// CI runs this file under `-p node` too.
void main() {
  for (final type in ExerciseType.values) {
    for (final seed in tierSeeds) {
      test('${type.name}, every tier, seed $seed', () {
        expect(
          tierSequence(type, seed),
          tierSequenceReferences['${type.name} | $seed'],
        );
      });
    }
  }
  for (final seed in tierSeeds) {
    test('a game of every type, seed $seed', () {
      expect(gameSequence(seed), gameSequenceReferences[seed]);
    });
  }
}
