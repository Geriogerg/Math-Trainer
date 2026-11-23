/// A level, kept in **integer hundredths**: 3742 is level 37.42 (plan,
/// Phase 1 commit 2; architecture rule 18). Range [0.00, 100.00]
/// (`doc/levels.md`: everyone starts at 0, the level of an operation never
/// played).
///
/// Why hundredths: with integer levels, every update was rounded to a whole
/// level, which swallowed every step under 0.5 — an extra dead band that
/// made convergence take 45–90 sessions (`doc/decisions.md`, check of Phase
/// 0 commit 5). Why an integer and not a `double`: the server replays level
/// updates (Phase 2) and the leaderboard orders on this value; an integer
/// stored and compared is the same on the VM, in JavaScript and in
/// WebAssembly, with no accumulated floating-point drift across sessions.
///
/// Readers use [whole] — generation (operand bounds), the score multiplier,
/// display. Only the level update and the leaderboard use [hundredths].
///
/// An extension type: zero cost at runtime (it *is* an `int`, stored as
/// one), but the compiler refuses to mix a `Level` with a whole-level `int`
/// — the mistake a unit change invites.
extension type const Level._(int hundredths) {
  /// Throws if [hundredths] is outside [0, 10000] (rule 13).
  factory Level.fromHundredths(int hundredths) {
    if (hundredths < minHundredths || hundredths > maxHundredths) {
      throw ArgumentError.value(
        hundredths,
        'hundredths',
        'must be between $minHundredths and $maxHundredths.',
      );
    }
    return Level._(hundredths);
  }

  /// A whole level (0 to 100), e.g. a starting level or a stored level from
  /// before schema v4. Throws outside [0, 100].
  factory Level.whole(int whole) {
    if (whole < 0 || whole > 100) {
      throw ArgumentError.value(whole, 'whole', 'must be between 0 and 100.');
    }
    return Level._(whole * 100);
  }

  /// [hundredths] clamped into the valid range — for the level update,
  /// whose result may overshoot the bounds before clamping.
  factory Level.clamped(int hundredths) => Level._(
    hundredths < minHundredths
        ? minHundredths
        : (hundredths > maxHundredths ? maxHundredths : hundredths),
  );

  static const minHundredths = 0;
  static const maxHundredths = 10000;

  /// Level 0: where everyone starts, the level of an operation never
  /// played (`doc/levels.md`).
  static const Level zero = Level._(0);

  /// The whole part (37 for 37.99): what generation reads and what the
  /// player sees. Truncation, not rounding, so the displayed level is the
  /// one that sets the difficulty.
  int get whole => hundredths ~/ 100;

  /// Level as a fraction, for averages and display only — never stored,
  /// never compared for ranking.
  double get value => hundredths / 100;
}
