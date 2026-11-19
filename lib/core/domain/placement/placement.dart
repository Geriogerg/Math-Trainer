import '../leveling/level.dart';
import '../models/exercise_type.dart';

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
    required this.passMaxElapsedMs,
    required this.sessionsPlayedAfter,
  });

  final int version;

  /// Where every staircase starts (whole level).
  final int startLevel;

  /// First move, in hundredths; halved (`~/ 2`) after every answer.
  final int firstStepHundredths;

  final int questionsPerType;

  /// An answer "passes" (the staircase goes up) if right **and** given
  /// within this time. Right but slow fails: the level targets fast and
  /// right answers (`p_cible` weighs speed), not right at any speed.
  final int passMaxElapsedMs;

  /// `sessionsPlayed` written to the level cache of a placed operation:
  /// below 3, the next sessions still move with the calibration boost
  /// (`confidenceFor`).
  final int sessionsPlayedAfter;

  int get questionCount => questionsPerType * placementTypes.length;
}

/// Version 1 — chosen by simulation (`tool/placement_check.dart`,
/// `doc/decisions.md`); **provisional** until the owner confirms.
const placementRulesV1 = PlacementRules(
  version: 1,
  startLevel: 35,
  firstStepHundredths: 2500,
  questionsPerType: 6,
  passMaxElapsedMs: 3000,
  sessionsPlayedAfter: 0,
);

/// Every version a stored placement may have used.
const placementRulesByVersion = {1: placementRulesV1};

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

/// Whether an answer moves the staircase up.
bool placementPassed({
  required bool isCorrect,
  required int elapsedMs,
  required PlacementRules rules,
}) => isCorrect && elapsedMs <= rules.passMaxElapsedMs;

/// The type of the [index]-th question (0-based): the four operations in
/// turn, so each staircase advances evenly and an interrupted placement
/// still has a little of each.
ExerciseType placementTypeAt(int index) =>
    placementTypes[index % placementTypes.length];

/// The staircases after [answers] — `(isCorrect, elapsedMs)` in the order
/// they were given, question `i` being of type [placementTypeAt]`(i)`.
Map<ExerciseType, Staircase> replayStaircases(
  List<({bool isCorrect, int elapsedMs})> answers,
  PlacementRules rules,
) {
  final stairs = {
    for (final type in placementTypes) type: Staircase.start(rules),
  };
  for (var i = 0; i < answers.length; i++) {
    final type = placementTypeAt(i);
    stairs[type] = stairs[type]!.after(
      passed: placementPassed(
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
  PlacementRules rules,
) {
  if (answers.length != rules.questionCount) {
    throw ArgumentError.value(
      answers.length,
      'answers',
      'must hold exactly ${rules.questionCount} answers (a full placement).',
    );
  }
  return replayStaircases(
    answers,
    rules,
  ).map((type, stair) => MapEntry(type, stair.level));
}
