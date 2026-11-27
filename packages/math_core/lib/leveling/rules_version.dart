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
  /// spec's long addition and subtraction tables (section 5). Its pattern
  /// questions had one size for every tier — 2²⁰ at level 15 — and 30 % of
  /// a game came from the tier below: fixed in [v5].
  v4(4),

  /// Pattern questions sized by tier (`doc/levels.md` v1.4): each family
  /// grows with the tier, within the spec's size table and its hard limit;
  /// no review questions — every question from the player's tier. v3's
  /// level update. Levels carry over: the same scale, no reset. Its √ of
  /// powers of 2 mirrored powers of 2 two tiers later: one question per
  /// band (√64 was 1 root question in 5 at T3) — [v6] widened it.
  v5(5),

  /// `doc/levels.md` v1.5: v5, with √ of powers of 2 sized by its own row
  /// (√64 to √1 024 at T3–T4, √4 096 to √65 536 from T5). v3's level
  /// update; levels carry over.
  v6(6),

  /// Phase 4 (plan v3.5): v6, plus up to 20 % of a Levelling game's
  /// questions re-asking the player's due weak spots — **from the current
  /// tier only**, stored with the session (`PersistedSession.weakSpots`).
  /// Without weak spots a v7 game is a v6 game, question for question. v3's
  /// level update; levels carry over.
  v7(7),

  /// The Phase 4 close-out (plan v3.6): v7's questions and update; the
  /// weak-spot schedule also takes in a fact answered **correctly but
  /// slowly**, at box 2 ([slowFactsEnterSchedule]) — it changes which items
  /// are due, so which weak spots a game may hold. Each game's answers are
  /// scheduled under that game's own rules: v7 games keep v7's rule.
  v8(8),

  /// `doc/levels.md` v1.6 (Phase 6b, plan v4.0): **new generation** — every
  /// tier's standard questions and every pattern family a space of distinct
  /// questions drawn uniformly, never twice in a game while it has others,
  /// never twice in a row (`DrawsV9`); the new Powers, Roots and Integrals
  /// tables, no trivial factor above T0, both lengths at T8; the families
  /// resized (Swap, round division, round cubes, from-zero integrals) and
  /// grown, one with fewer than 4 questions at a tier skipped there;
  /// **weak spots at most ⌊n/5⌋ per operation** (v7–v8: ⌈n/5⌉). v8's
  /// schedule and v3's level constants — and **quitting counts**: a
  /// Levelling game with one answer moves levels however it ends, its
  /// unanswered questions timeouts ([quitCounts]).
  v9(9);

  const RulesVersion(this.number);

  final int number;

  /// What new sessions are played under.
  static const current = v9;

  /// The rules a server built from this code replays (validation refuses
  /// the others). The server says so in its `/health` (`rules`), and the
  /// app holds a session back, pending, until the server it talks to knows
  /// its rules — an older server would refuse it for good.
  static const replayed = [v2, v3, v4, v5, v6, v7, v8, v9];

  /// Played before the Levels phase's transition: its levels are on the
  /// old scale (1–100 from placement), never compared with the others.
  bool get retired => switch (this) {
    v1 => true,
    v2 || v3 || v4 || v5 || v6 || v7 || v8 || v9 => false,
  };

  /// Whether a fact answered correctly but slowly enters the weak-spot
  /// schedule (at box 2) — from rules v8 (plan v3.6, Phase 4 outcome).
  bool get slowFactsEnterSchedule => switch (this) {
    v1 || v2 || v3 || v4 || v5 || v6 || v7 => false,
    v8 || v9 => true,
  };

  /// Whether a game may hold weak spots (`PersistedSession.weakSpots`) and
  /// practice kinds exist: rules v7 on.
  bool get hasWeakSpots => switch (this) {
    v1 || v2 || v3 || v4 || v5 || v6 => false,
    v7 || v8 || v9 => true,
  };

  /// Whether a Levelling game left before its last question still moves
  /// levels, its unanswered questions counted as timeouts (`doc/levels.md`
  /// v1.6 section 3, "Quitting never pays"; review M4): from rules v9. Under
  /// v2–v8 an interrupted game moved no level.
  bool get quitCounts => switch (this) {
    v1 || v2 || v3 || v4 || v5 || v6 || v7 || v8 => false,
    v9 => true,
  };

  /// Whether a game's questions come from rules v9's spaces, drawn without
  /// repeats (`doc/levels.md` v1.6); from v9 also its weak spots' tiers.
  bool get drawsWithoutRepeats => switch (this) {
    v1 || v2 || v3 || v4 || v5 || v6 || v7 || v8 => false,
    v9 => true,
  };

  /// Throws [ArgumentError] for a number no version has (rule 13).
  static RulesVersion of(int number) {
    for (final version in values) {
      if (version.number == number) return version;
    }
    throw ArgumentError.value(number, 'number', 'is not a rules version.');
  }
}
