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
  placementV2;

  bool get isPlacement => this != game;
}
