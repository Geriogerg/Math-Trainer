/// What a session was. Its [name] is the stored discriminant
/// (`sessions.kind`): **renaming a value breaks history**, like
/// `ExerciseType`. A placement kind carries its rules' version, since a
/// stored placement replays only with the rules it was played with
/// (`placementRulesByVersion`).
enum SessionKind {
  /// A normal game: questions from (seed, frozen levels), level updates by
  /// `LevelUpdater`.
  game,

  /// The placement test, rules version 1 (`placementRulesV1`): adaptive
  /// questions, starting levels by `placementLevels`.
  placementV1,

  /// The placement test, rules version 2 (`placementRulesV2`).
  placementV2,

  /// The first game on never-played operations, played as a short
  /// placement on them (rules version 3, `typePlacementRules`; Phase 3a
  /// commit 7). Which operations: the session's `enabledTypes`.
  typePlacementV3,

  /// A Training game (Redesign phase commit 3): questions like a game, at
  /// the fixed level of its difficulty (`TrainingDifficulty`), frozen in the
  /// session's levels for the replay. Never moves a level, never ranked.
  training;

  bool get isPlacement => switch (this) {
    placementV1 || placementV2 || typePlacementV3 => true,
    game || training => false,
  };

  /// A placement on the session's own operations, rather than the four
  /// basic ones.
  bool get isTypePlacement => this == typePlacementV3;
}
