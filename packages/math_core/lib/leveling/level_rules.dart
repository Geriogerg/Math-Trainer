import 'rules_version.dart';

/// The constants of the level update (`doc/levels.md`, section 3), one set
/// per rules version ([LevelRules.of]). Few and readable on purpose (the
/// spec's principle 5); every value is a guess Phase 3b calibrates.
/// Percentages and credits are integers, so the update needs nothing but
/// integer `+ − × ÷` (rule 18).
class LevelRules {
  /// Throws on values that would make the update meaningless (rule 13).
  LevelRules({
    required this.slowCreditPercent,
    required this.deadBandLowPercent,
    required this.deadBandHighPercent,
    required this.capDownLevels,
    this.upSpanPercent = 25,
    this.downSpanPercent = 35,
    this.capUpLevels = const [
      (questions: 20, levels: 5),
      (questions: 10, levels: 4),
      (questions: 0, levels: 3),
    ],
  }) {
    if (slowCreditPercent < 0 || slowCreditPercent > fluentCreditPercent) {
      throw ArgumentError.value(
        slowCreditPercent,
        'slowCreditPercent',
        'must be between 0 and $fluentCreditPercent.',
      );
    }
    if (deadBandLowPercent < 0 ||
        deadBandLowPercent > deadBandHighPercent ||
        deadBandHighPercent > 100) {
      throw ArgumentError.value(
        (deadBandLowPercent, deadBandHighPercent),
        'deadBand',
        'must satisfy 0 <= low <= high <= 100.',
      );
    }
    if (upSpanPercent <= 0 || downSpanPercent <= 0) {
      throw ArgumentError.value(
        (upSpanPercent, downSpanPercent),
        'spans',
        'must be positive.',
      );
    }
    if (capDownLevels < 0 ||
        capUpLevels.isEmpty ||
        capUpLevels.last.questions > 0 ||
        capUpLevels.any((c) => c.levels < 0)) {
      throw ArgumentError.value(
        capUpLevels,
        'caps',
        'must be non-negative, with a cap for any number of questions.',
      );
    }
  }

  /// A fluent answer's credit, in percent (1.0).
  static const fluentCreditPercent = 100;

  /// Rules v2: `doc/levels.md` section 3 as written — slow 0.75, dead band
  /// 0.55–0.65, down cap 2.
  static final v2 = LevelRules(
    slowCreditPercent: 75,
    deadBandLowPercent: 55,
    deadBandHighPercent: 65,
    capDownLevels: 2,
  );

  /// Rules v3 (Levels close-out, `doc/decisions.md`): only the three
  /// constants the plan opens to tuning move — slow 0.85, dead band
  /// 0.62–0.72, down cap 3 — so a player stalls between 60 and 70 % correct
  /// answers instead of creeping up from ~54 %.
  static final v3 = LevelRules(
    slowCreditPercent: 85,
    deadBandLowPercent: 62,
    deadBandHighPercent: 72,
    capDownLevels: 3,
  );

  /// The constants [version] was played under. Throws for v1, retired: its
  /// levels are never computed again (`doc/levels.md`, section 4).
  static LevelRules of(RulesVersion version) => switch (version) {
    RulesVersion.v1 => throw ArgumentError.value(
      version,
      'version',
      'is retired: its levels are never computed again.',
    ),
    RulesVersion.v2 => v2,
    RulesVersion.v3 => v3,
  };

  /// A correct answer slower than the fluent time, within 30 s, in percent
  /// of a fluent one ([fluentCreditPercent]); a wrong one or a timeout is 0.
  final int slowCreditPercent;

  /// Quality (mean credit, in percent) from which the level goes down below
  /// and up above: between the two, the player is at their level.
  final int deadBandLowPercent;
  final int deadBandHighPercent;

  /// Quality above the dead band that earns the whole [capUpLevels]: 25
  /// points.
  final int upSpanPercent;

  /// Quality below the dead band that costs the whole [capDownLevels]: 35
  /// points.
  final int downSpanPercent;

  /// The most a game takes off an operation, in levels.
  final int capDownLevels;

  /// The most a game adds to an operation, by its number of questions: the
  /// first entry whose `questions` is reached. Largest `questions` first.
  final List<({int questions, int levels})> capUpLevels;

  /// [capUpLevels] for [questions] answers on one operation: 3 for 4 or 5,
  /// 4 for 10, 5 for 20 (`doc/levels.md`).
  int capUpFor(int questions) {
    for (final cap in capUpLevels) {
      if (questions >= cap.questions) return cap.levels;
    }
    throw ArgumentError.value(questions, 'questions', 'has no cap.');
  }

  @override
  String toString() =>
      'LevelRules(slow $slowCreditPercent %, dead band '
      '$deadBandLowPercent–$deadBandHighPercent %, down cap $capDownLevels)';
}
