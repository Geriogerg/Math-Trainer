/// The constants of the level update, rules v2 (`doc/levels.md`, section 3).
/// Few and readable on purpose (the spec's principle 5); every value is a
/// first guess Phase 3b calibrates. Percentages and credits are integers,
/// so the update needs nothing but integer `+ − × ÷` (rule 18).
class LevelRules {
  /// Throws on values that would make the update meaningless (rule 13).
  LevelRules({
    this.slowCreditQuarters = 3,
    this.deadBandLowPercent = 55,
    this.deadBandHighPercent = 65,
    this.upSpanPercent = 25,
    this.downSpanPercent = 35,
    this.capDownLevels = 2,
    this.capUpLevels = const [
      (questions: 20, levels: 5),
      (questions: 10, levels: 4),
      (questions: 0, levels: 3),
    ],
  }) {
    if (slowCreditQuarters < 0 || slowCreditQuarters > 4) {
      throw ArgumentError.value(
        slowCreditQuarters,
        'slowCreditQuarters',
        'must be between 0 and 4.',
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

  /// The spec's values.
  static final standard = LevelRules();

  /// A correct answer slower than the fluent time, within 30 s, in quarters
  /// of a fluent one: 3 = 0.75. A fluent answer is 4, a wrong one or a
  /// timeout 0.
  final int slowCreditQuarters;

  /// Quality (mean credit, in percent) from which the level goes down below
  /// and up above: between the two, the player is at their level.
  final int deadBandLowPercent;
  final int deadBandHighPercent;

  /// Quality above the dead band that earns the whole [capUpLevels]: 25
  /// points, so q = 0.90 or more.
  final int upSpanPercent;

  /// Quality below the dead band that costs the whole [capDownLevels]: 35
  /// points, so q = 0.20 or less.
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
}
