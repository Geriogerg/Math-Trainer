/// The rules a session was played under — generation and level update
/// together (`doc/levels.md`, section 4). Stored with every session (app
/// schema v10, the upload's `rulesVersion`) so the server replays each
/// session with its own rules, and so data from different rules never mix.
///
/// [number] is the stored value: never renumber one.
enum RulesVersion {
  /// Until the Levels phase: levels 1–100, operand curves by level, the
  /// `p_cible` formula, placement and type placement. Sessions stored
  /// without a version are v1. **Retired** at the Levels phase's transition
  /// (commit 4): its code is gone, its sessions stay in history, never
  /// replayed — the server refuses one uploaded late (`rulesRetired`).
  v1(1),

  /// The Levels phase (`doc/levels.md` v1): levels 0–100, ten tiers per
  /// operation, credit and quality, no placement. Its addition and
  /// subtraction follow an earlier draft's tables (4 digits at most), not
  /// the spec's section 5 — found at the Patterns and Method phase, fixed
  /// in [v4]; kept as they were, so v2 and v3 games replay.
  v2(2),

  /// The Levels close-out's tuning (`doc/plan.md` v3.2): v2's questions,
  /// v2's level update with three constants moved (`LevelRules.v3`).
  /// Levels carry over from v2: the same scale, no reset.
  v3(3),

  /// The Patterns and Method phase (`doc/levels.md` v1.2): v3's level
  /// update; new generation — pattern questions (section 5b) and the
  /// spec's long addition and subtraction tables (section 5).
  v4(4);

  const RulesVersion(this.number);

  final int number;

  /// What new sessions are played under.
  static const current = v4;

  /// The rules a server built from this code replays (validation refuses
  /// the others). The server says so in its `/health` (`rules`), and the
  /// app holds a session back, pending, until the server it talks to knows
  /// its rules — an older server would refuse it for good.
  static const replayed = [v2, v3, v4];

  /// Played before the Levels phase's transition: its levels are on the
  /// old scale (1–100 from placement), never compared with the others.
  bool get retired => switch (this) {
    v1 => true,
    v2 || v3 || v4 => false,
  };

  /// Throws [ArgumentError] for a number no version has (rule 13).
  static RulesVersion of(int number) {
    for (final version in values) {
      if (version.number == number) return version;
    }
    throw ArgumentError.value(number, 'number', 'is not a rules version.');
  }
}
