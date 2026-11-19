// Same (seed, config) → same questions and same level updates, on the Dart
// VM and compiled to JavaScript (architecture rule 18, plan Phase 1 commit
// 1). Runs in both `dart test test/domain` and `dart test test/domain -p
// node` (CI runs both). Cases: `determinism_cases.dart`; references,
// generated on the VM: `determinism_references.dart`.
//
// A failure on one platform only means players and the server would
// disagree: honest sessions would be rejected in Phase 2. Fix the cause —
// never regenerate the references to make it pass.

import 'package:test/test.dart';

import 'determinism_cases.dart';
import 'determinism_references.dart';

void main() {
  group('session sequences', () {
    for (final setup in determinismSetups) {
      for (final seed in determinismSeeds) {
        final key = '${setup.name} | $seed';
        test(key, () {
          expect(
            sessionSequence(seed, setup),
            sessionSequenceReferences[key],
            reason: 'reference missing or sequence changed',
          );
        });
      }
    }
  });

  group('endless sequences (uniform type draw)', () {
    for (final seed in determinismSeeds) {
      test('seed $seed', () {
        expect(endlessSequence(seed), endlessSequenceReferences[seed]);
      });
    }
  });

  group('placement sequences (adaptive)', () {
    for (final pattern in placementPatterns.keys) {
      for (final seed in determinismSeeds) {
        final key = '$pattern | $seed';
        test(key, () {
          expect(
            placementSequence(seed, pattern),
            placementSequenceReferences[key],
            reason: 'reference missing or sequence changed',
          );
        });
      }
    }
  });

  test('level update grid', () {
    expect(levelUpdateGrid(), levelUpdateGridReference);
  });

  test('every case has a reference, and no reference is stale', () {
    expect(sessionSequenceReferences.keys.toSet(), {
      for (final setup in determinismSetups)
        for (final seed in determinismSeeds) '${setup.name} | $seed',
    });
    expect(endlessSequenceReferences.keys.toSet(), determinismSeeds.toSet());
  });
}
