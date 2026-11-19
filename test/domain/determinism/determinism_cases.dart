// Cross-platform determinism cases (Phase 1, commit 1; architecture rule
// 18). Players generate in the browser (JavaScript); the server will replay
// on the Dart VM (Phase 2). Each case is computed here the way the app
// computes it, and turned into a string; the references pinned in
// `determinism_references.dart` were produced on the VM by
// `tool/determinism_references.dart`, and `determinism_test.dart` checks
// that both `dart test test/domain` (VM) and `dart test test/domain -p node`
// (JavaScript) reproduce them character for character.
//
// Shared by the test and the tool: never import Flutter here.

import 'package:math_trainer/core/domain/generation/composite_exercise_generator.dart';
import 'package:math_trainer/core/domain/generation/debt_aware_type_selection_strategy.dart';
import 'package:math_trainer/core/domain/generation/local_exercise_source.dart';
import 'package:math_trainer/core/domain/generation/session_length.dart';
import 'package:math_trainer/core/domain/leveling/answer_outcome.dart';
import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/leveling/level_updater.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/exercise_codec.dart';
import 'package:math_trainer/core/domain/placement/placement_exercise_source.dart';

/// Seeds the app really produces (`DateTime.now().millisecondsSinceEpoch`,
/// about 2^41) and edge values of `Random(seed)`: 0, negative, around 2^32
/// (where a JavaScript port of a 64-bit seed splits it), and the largest
/// integer JavaScript represents exactly (2^53 − 1).
const determinismSeeds = <int>[
  0,
  1,
  42,
  -7,
  2147483647,
  4294967295,
  4294967296,
  4294967301,
  1763510400000,
  1763548212345,
  1795000000999,
  9007199254740991,
];

/// (types, whole levels, sessions already played per type) — the inputs besides
/// the seed that shape a sequence. `sessionsPlayedByType` is not part of
/// `SessionConfig` but changes the interleaving order (debt-aware strategy).
typedef GenerationSetup = ({
  String name,
  Map<ExerciseType, int> levels,
  Map<ExerciseType, int> sessionsPlayed,
});

const _all = ExerciseType.values;

final determinismSetups = <GenerationSetup>[
  (
    name: 'default pair, level 1',
    levels: {ExerciseType.addition: 1, ExerciseType.subtraction: 1},
    sessionsPlayed: {},
  ),
  (
    name: 'four basics, mid levels, uneven debt',
    levels: {
      ExerciseType.addition: 37,
      ExerciseType.subtraction: 52,
      ExerciseType.multiplication: 18,
      ExerciseType.division: 64,
    },
    sessionsPlayed: {
      ExerciseType.addition: 9,
      ExerciseType.subtraction: 2,
      ExerciseType.multiplication: 5,
    },
  ),
  (
    name: 'all seven, level 100 (capped length, rotation by debt)',
    levels: {for (final t in _all) t: 100},
    sessionsPlayed: {for (final t in _all) t: 3 + t.index % 3},
  ),
  (
    name: 'all seven, scattered levels',
    levels: {for (final t in _all) t: 1 + (t.index * 31) % 100},
    sessionsPlayed: {},
  ),
  (
    name: 'powers, roots, percentages',
    levels: {
      ExerciseType.power: 73,
      ExerciseType.squareRoot: 46,
      ExerciseType.percentage: 88,
    },
    sessionsPlayed: {ExerciseType.percentage: 1},
  ),
  for (final t in _all)
    (name: 'single ${t.name}, level 59', levels: {t: 59}, sessionsPlayed: {}),
];

/// The sequence of one session, built exactly as `buildSessionController`
/// builds it (`lib/composition_root.dart`), as `type:operands;...`.
String sessionSequence(int seed, GenerationSetup setup) {
  final enabledTypes = setup.levels.keys.toSet();
  final exerciseCount = sessionLengthFor(
    activeTypeCount: enabledTypes.length,
    nMin: LevelingRules().nMin,
    cap: 24,
  );
  final source = LocalExerciseSource(
    generator: CompositeExerciseGenerator(
      enabledTypes: enabledTypes,
      levels: {
        for (final e in setup.levels.entries) e.key: Level.whole(e.value),
      },
      strategy: DebtAwareTypeSelectionStrategy(
        exerciseCount: exerciseCount,
        nMin: LevelingRules().nMin,
        sessionsPlayedByType: setup.sessionsPlayed,
      ),
    ),
    seed: seed,
  );
  return [
    for (var i = 0; i < exerciseCount; i++) _describe(source.next()),
  ].join(';');
}

/// The endless mode (no strategy: one uniform type draw per question), 40
/// draws over every type — exercises the type draw from the same stream.
String endlessSequence(int seed) {
  final source = LocalExerciseSource(
    generator: CompositeExerciseGenerator(
      enabledTypes: _all.toSet(),
      levels: {for (final t in _all) t: Level.whole(1 + (t.index * 17) % 100)},
    ),
    seed: seed,
  );
  return [for (var i = 0; i < 40; i++) _describe(source.next())].join(';');
}

String _describe(Exercise exercise) {
  final d = describeExerciseForStorage(exercise);
  return '${d.operationType}:${d.operands.values.join(',')}';
}

/// Answer patterns for the placement test (Phase 1 commit 6): its questions
/// depend on the seed **and** the answers so far, so both vary.
final placementPatterns = <String, PlacementAnswer Function(int i)>{
  'all pass': (_) => (isCorrect: true, elapsedMs: 1200),
  'all fail': (_) => (isCorrect: false, elapsedMs: 15000),
  'alternate': (i) => (isCorrect: i.isEven, elapsedMs: 2000),
  'slow right': (i) => (isCorrect: true, elapsedMs: 2500 + i * 61),
};

/// A full placement's questions, regenerated as the server will
/// (`replayPlacementQuestions`).
String placementSequence(int seed, String pattern) => replayPlacementQuestions(
  seed: seed,
  answers: [for (var i = 0; i < 24; i++) placementPatterns[pattern]!(i)],
).map(_describe).join(';');

/// Level updates over a grid of synthetic sessions: correctness patterns ×
/// elapsed times × lengths × confidence × starting levels. Exercises the
/// floating-point path (mean, dead band, `sqrt` volume weight, clamp,
/// `round`), where a platform difference would show first. Levels in
/// hundredths since Phase 1 commit 2 (starting levels with a fraction
/// included).
String levelUpdateGrid() {
  final updater = LevelUpdater();
  final out = StringBuffer();
  const patterns = [0x0, 0x5, 0x7, 0xB, 0xE, 0xF];
  const elapsed = [0, 1999, 2000, 3500, 5000, 7999, 8000, 15000];
  const lengths = [3, 4, 5, 8, 12, 16, 24];
  const starts = [100, 200, 3742, 9901, 10000];
  for (final pattern in patterns) {
    for (final ms in elapsed) {
      for (final n in lengths) {
        for (final confidence in ConfidenceMultiplier.values) {
          for (final start in starts) {
            final answers = [
              for (var i = 0; i < n; i++)
                AnswerOutcome(
                  isCorrect: (pattern >> (i % 4)) & 1 == 1,
                  // Spread times so the mean is rarely a round number.
                  elapsedMs: ms + (i * 137) % 900,
                ),
            ];
            out.write(
              updater
                  .update(
                    currentLevel: Level.fromHundredths(start),
                    answers: answers,
                    confidence: confidence,
                  )
                  .hundredths,
            );
            out.write(',');
          }
        }
      }
    }
  }
  return out.toString();
}
