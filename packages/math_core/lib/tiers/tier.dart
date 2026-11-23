import '../leveling/level.dart';

/// One of the ten bands of ten levels (`doc/levels.md`, section 2): T0 =
/// levels 0–9, T1 = 10–19 … T9 = 90–100. Under rules v2 the tier of the
/// level frozen at the start of a game decides what the questions are made
/// of (section 5) and how fast a fluent answer is.
///
/// An enum, not an int: every `switch` on it is exhaustive, so a tier
/// without content does not compile (rule 11's spirit).
enum Tier {
  t0,
  t1,
  t2,
  t3,
  t4,
  t5,
  t6,
  t7,
  t8,
  t9;

  /// The tier of [level]'s whole part; 100 is in T9.
  static Tier of(Level level) {
    final index = level.whole ~/ 10;
    return values[index > 9 ? 9 : index];
  }

  /// The tier a review question is drawn from: the one below, none at T0.
  Tier? get below => index == 0 ? null : values[index - 1];

  /// "T4", as the spec writes it.
  String get label => 'T$index';
}

/// How many of an operation's [questions] in a game are review questions
/// from the tier below (`doc/levels.md`, section 2): 30 %, rounded half up
/// — 1 of 4, 2 of 5, 3 of 10, 6 of 20; none at T0.
int reviewQuestionCount(Tier tier, int questions) =>
    tier.below == null ? 0 : (3 * questions + 5) ~/ 10;
