import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:test/test.dart';

import 'tier_cases.dart';
import 'tier_references.dart';
import 'tier_references_v4.dart';
import 'tier_references_v5.dart';
import 'tier_references_v6.dart';

/// Rules v2's, v4's and v5's questions are the same on the VM and in
/// JavaScript
/// (rule 18):
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
  group('rules v4', () {
    for (final type in ExerciseType.values) {
      for (final seed in tierSeeds) {
        test('${type.name}, every tier, seed $seed', () {
          expect(
            patternedSequence(type, seed),
            patternedSequenceReferences['${type.name} | $seed'],
          );
        });
      }
    }
    for (final seed in tierSeeds) {
      test('every pattern family, seed $seed', () {
        expect(familySequence(seed), familySequenceReferences[seed]);
      });
      test('a game of every type, seed $seed', () {
        expect(
          gameSequence(seed, RulesVersion.v4),
          gameSequenceV4References[seed],
        );
      });
    }
  });
  group('rules v5', () {
    for (final type in ExerciseType.values) {
      for (final seed in tierSeeds) {
        test('${type.name}, every tier, seed $seed', () {
          expect(
            patternedSequenceV5(type, seed),
            patternedSequenceV5References['${type.name} | $seed'],
          );
        });
      }
    }
    for (final seed in tierSeeds) {
      test('every pattern family at every tier, seed $seed', () {
        expect(familySequenceV5(seed), familySequenceV5References[seed]);
      });
      test('a game of every type, seed $seed', () {
        expect(
          gameSequence(seed, RulesVersion.v5),
          gameSequenceV5References[seed],
        );
      });
    }
  });
  group('rules v6', () {
    for (final type in ExerciseType.values) {
      for (final seed in tierSeeds) {
        test('${type.name}, every tier, seed $seed', () {
          expect(
            patternedSequenceV6(type, seed),
            patternedSequenceV6References['${type.name} | $seed'],
          );
        });
      }
    }
    for (final seed in tierSeeds) {
      test('every pattern family at every tier, seed $seed', () {
        expect(familySequenceV6(seed), familySequenceV6References[seed]);
      });
      test('a game of every type, seed $seed', () {
        expect(
          gameSequence(seed, RulesVersion.v6),
          gameSequenceV6References[seed],
        );
      });
    }
  });
}
