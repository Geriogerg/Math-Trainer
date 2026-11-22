import '../leveling/level.dart';
import '../leveling/leveling_rules.dart';
import '../models/exercise_type.dart';
import '../models/session_kind.dart';

/// Placement test (plan, Phase 1 commit 6): about a minute on the four
/// basic operations, one adaptive **staircase** per operation, that sets
/// the starting levels of a new player. Powers, square roots and
/// percentages are not placed: they start at level 1 with the calibration
/// boost, as before.
///
/// Everything here is pure and integer (levels and steps in hundredths, a
/// halving by `~/ 2`): the server replays a placement exactly like a game
/// (rule 18), from the seed and the answers in order.

/// The four placed operations, in the order the questions rotate through.
const placementTypes = [
  ExerciseType.addition,
  ExerciseType.subtraction,
  ExerciseType.multiplication,
  ExerciseType.division,
];

/// A placement's parameters. **Versioned**: a stored placement session
/// records [version] in its kind, and replaying it must use the same
/// values — change a value, bump the version, keep the old one replayable.
class PlacementRules {
  const PlacementRules({
    required this.version,
    required this.startLevel,
    required this.firstStepHundredths,
    required this.questionsPerType,
    required this.passMaxElapsedMsByType,
    required this.sessionsPlayedAfter,
  });

  final int version;

  /// Where every staircase starts (whole level).
  final int startLevel;

  /// First move, in hundredths; halved (`~/ 2`) after every answer.
  final int firstStepHundredths;

  final int questionsPerType;

  /// An answer "passes" (the staircase goes up) if right **and** given
  /// within its operation's time. Right but slow fails: the level targets
  /// fast and right answers (`p_cible` weighs speed), not right at any
  /// speed. One entry per placed operation.
  final Map<ExerciseType, int> passMaxElapsedMsByType;

  int passMaxElapsedMsFor(ExerciseType type) {
    final ms = passMaxElapsedMsByType[type];
    if (ms == null) {
      throw ArgumentError.value(type, 'type', 'is not a placed operation.');
    }
    return ms;
  }

  /// `sessionsPlayed` written to the level cache of a placed operation:
  /// below 3, the next sessions still move with the calibration boost
  /// (`confidenceFor`).
  final int sessionsPlayedAfter;

  int get questionCount => questionsPerType * placementTypes.length;
}

/// Version 1 (Phase 1): 6 questions per operation, a flat 3 s. Kept so
/// that stored `placementV1` sessions still replay — never edit it.
const placementRulesV1 = PlacementRules(
  version: 1,
  startLevel: 35,
  firstStepHundredths: 2500,
  questionsPerType: 6,
  passMaxElapsedMsByType: {
    ExerciseType.addition: 3000,
    ExerciseType.subtraction: 3000,
    ExerciseType.multiplication: 3000,
    ExerciseType.division: 3000,
  },
  sessionsPlayedAfter: 0,
);

/// How the pass time of version 2 follows `t_rapide`: 1.5 × the
/// operation's `t_rapide` (`tool/placement_check.dart`, `doc/decisions.md`).
const placementPassTimeOverTRapide = 1.5;

/// Version 2 (owner, end of Phase 1): 5 questions per operation (shorter,
/// near 80 s), the pass time **per operation**, 1.5 × its `t_rapide`.
/// `LevelingRules` has a single `t_rapide` (2 s) today, so the four values
/// are equal until Phase 3 gives each operation its own; a test keeps them
/// tied to `LevelingRules`.
const placementRulesV2 = PlacementRules(
  version: 2,
  startLevel: 35,
  firstStepHundredths: 2500,
  questionsPerType: 5,
  passMaxElapsedMsByType: {
    ExerciseType.addition: 3000,
    ExerciseType.subtraction: 3000,
    ExerciseType.multiplication: 3000,
    ExerciseType.division: 3000,
  },
  sessionsPlayedAfter: 0,
);

/// The rules a new placement uses.
const currentPlacementRules = placementRulesV2;

/// Version 3 (plan v2.3, Phase 3a commit 7): the **type placement** — the
/// first game on an operation the player never played is a short
/// placement on the never-played operations of their selection, any of the
/// seven (powers, roots and percentages otherwise take ~65 games to climb
/// from level 1). Same staircase as version 2, per operation: start 35,
/// first step 25 levels, 5 questions, pass time 1.5 × `t_rapide`. The
/// session stores which operations it placed (`enabledTypes`) and their
/// rotation (`typeSequence`, `typePlacementSequence`).
const typePlacementRules = PlacementRules(
  version: 3,
  startLevel: 35,
  firstStepHundredths: 2500,
  questionsPerType: 5,
  passMaxElapsedMsByType: {
    ExerciseType.addition: 3000,
    ExerciseType.subtraction: 3000,
    ExerciseType.multiplication: 3000,
    ExerciseType.division: 3000,
    ExerciseType.power: 3000,
    ExerciseType.squareRoot: 3000,
    ExerciseType.percentage: 3000,
  },
  sessionsPlayedAfter: 0,
);

/// A type placement's questions: [types] in turn (by enum index, the
/// stored order of `ExerciseType`), `questionsPerType` each.
List<ExerciseType> typePlacementSequence(
  Set<ExerciseType> types, {
  PlacementRules rules = typePlacementRules,
}) {
  if (types.isEmpty) {
    throw ArgumentError.value(types, 'types', 'is empty.');
  }
  final ordered = types.toList()..sort((a, b) => a.index - b.index);
  return [
    for (var i = 0; i < rules.questionsPerType * ordered.length; i++)
      ordered[i % ordered.length],
  ];
}

/// The pass times `placementRulesV2` must hold for [rules]: 1.5 ×
/// `t_rapide`, for each placed operation.
Map<ExerciseType, int> placementPassTimesFor(LevelingRules rules) => {
  for (final type in placementTypes)
    type: (rules.tRapideMs * placementPassTimeOverTRapide).round(),
};

/// The rules a stored placement of [kind] was played with. Throws for a
/// game (rule 13).
PlacementRules placementRulesFor(SessionKind kind) => switch (kind) {
  SessionKind.placementV1 => placementRulesV1,
  SessionKind.placementV2 => placementRulesV2,
  SessionKind.typePlacementV3 => typePlacementRules,
  SessionKind.game || SessionKind.training => throw ArgumentError.value(
    kind,
    'kind',
    'is not a placement.',
  ),
};

/// The session kind a placement with [rules] is stored as.
SessionKind placementKindFor(PlacementRules rules) => switch (rules.version) {
  1 => SessionKind.placementV1,
  2 => SessionKind.placementV2,
  3 => SessionKind.typePlacementV3,
  _ => throw ArgumentError.value(rules.version, 'rules.version', 'unknown.'),
};

/// One operation's staircase: the level of its next question and the
/// next move, both in hundredths.
class Staircase {
  const Staircase._(this.levelHundredths, this.stepHundredths);

  factory Staircase.start(PlacementRules rules) =>
      Staircase._(rules.startLevel * 100, rules.firstStepHundredths);

  final int levelHundredths;
  final int stepHundredths;

  /// The level the next question is generated at.
  Level get level => Level.clamped(levelHundredths);

  /// Up after a pass, down otherwise, then the step halves. The level is
  /// clamped at every move, so a staircase never wanders outside [1, 100].
  Staircase after({required bool passed}) => Staircase._(
    Level.clamped(
      levelHundredths + (passed ? stepHundredths : -stepHundredths),
    ).hundredths,
    stepHundredths ~/ 2,
  );
}

/// Whether an answer to a question of [type] moves the staircase up.
bool placementPassed({
  required ExerciseType type,
  required bool isCorrect,
  required int elapsedMs,
  required PlacementRules rules,
}) => isCorrect && elapsedMs <= rules.passMaxElapsedMsFor(type);

/// The type of the [index]-th question (0-based): the four operations in
/// turn, so each staircase advances evenly and an interrupted placement
/// still has a little of each.
ExerciseType placementTypeAt(int index) =>
    placementTypes[index % placementTypes.length];

/// Every question's type in a full placement under [rules] — what the
/// session stores as its type sequence.
List<ExerciseType> placementTypeSequence(PlacementRules rules) => [
  for (var i = 0; i < rules.questionCount; i++) placementTypeAt(i),
];

/// The staircases after [answers] — `(isCorrect, elapsedMs)` in the order
/// they were given, question `i` being of type [placementTypeAt]`(i)`, or
/// `sequence[i]` for a type placement (one staircase per type in it).
Map<ExerciseType, Staircase> replayStaircases(
  List<({bool isCorrect, int elapsedMs})> answers,
  PlacementRules rules, {
  List<ExerciseType>? sequence,
}) {
  if (sequence != null && answers.length > sequence.length) {
    throw ArgumentError.value(
      answers.length,
      'answers',
      'outnumber the ${sequence.length} planned questions.',
    );
  }
  final stairs = {
    for (final type in sequence?.toSet() ?? placementTypes)
      type: Staircase.start(rules),
  };
  for (var i = 0; i < answers.length; i++) {
    final type = sequence?[i] ?? placementTypeAt(i);
    stairs[type] = stairs[type]!.after(
      passed: placementPassed(
        type: type,
        isCorrect: answers[i].isCorrect,
        elapsedMs: answers[i].elapsedMs,
        rules: rules,
      ),
    );
  }
  return stairs;
}

/// Starting levels from a **complete** placement: each staircase's level
/// after its last answer. The pure function the plan asks for — the level
/// cache stays recomputable from history, and the server can replay it.
/// Throws if [answers] is not exactly one full placement (rule 13): an
/// interrupted placement sets no level.
Map<ExerciseType, Level> placementLevels(
  List<({bool isCorrect, int elapsedMs})> answers,
  PlacementRules rules, {
  List<ExerciseType>? sequence,
}) {
  final count = sequence?.length ?? rules.questionCount;
  if (answers.length != count) {
    throw ArgumentError.value(
      answers.length,
      'answers',
      'must hold exactly $count answers (a full placement).',
    );
  }
  return replayStaircases(
    answers,
    rules,
    sequence: sequence,
  ).map((type, stair) => MapEntry(type, stair.level));
}
