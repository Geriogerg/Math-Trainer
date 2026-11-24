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
  training,

  /// A Weak spots game (Phase 4): the player's due items, one question
  /// each, in the session's `weakSpots` order, at the player's levels
  /// (frozen). Practice: never moves a level, never ranked.
  weakSpots,

  /// A Drill (Phase 4): 10 questions of one tip's strategy — its families
  /// stored as the session's `weakSpots` (none: the tier's standard
  /// questions) — at the tier of its one frozen level. Practice.
  drill;

  bool get isPlacement => switch (this) {
    placementV1 || placementV2 || typePlacementV3 => true,
    game || training || weakSpots || drill => false,
  };

  /// The kinds a server built from this code accepts (validates and
  /// stores): its `/health` lists their names (`kinds`, Phase 4 close-out).
  /// The placements are history only, refused.
  static const acceptedByServer = [game, training, weakSpots, drill];

  /// What a server whose `/health` lists no kinds accepts: the servers
  /// before the Phase 4 close-out — the app holds the practice kinds back
  /// from them, as it holds a rules version back.
  static const acceptedWithoutList = [game, training];

  /// Only a Levelling game moves levels and counts for the boards.
  bool get movesLevels => this == game;

  /// Phase 4's practice games: a Weak spots game or a Drill.
  bool get isPractice => this == weakSpots || this == drill;

  /// A placement on the session's own operations, rather than the four
  /// basic ones.
  bool get isTypePlacement => this == typePlacementV3;
}
