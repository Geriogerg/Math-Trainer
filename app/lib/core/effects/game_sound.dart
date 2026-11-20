/// The game's sounds (Phase 5 commit 4, `doc/plan.md` section 6.2): short,
/// quiet, mixed so that twenty questions in a row never tire.
///
/// Fire and forget, like every effect: a method schedules its sound and
/// returns at once; it never throws, never waits.
abstract interface class GameSound {
  /// A key of the on-screen keypad.
  void keyTick();

  /// A right answer; [streak] (≥ 1) raises the chime's pitch.
  void correct(int streak);

  /// A wrong answer or a timeout: a low tone.
  void wrong();

  /// A level went up on the result screen (Phase 5 commit 6).
  void levelUp();
}

/// Silence: tests, and platforms without an implementation yet (mobile
/// until Phase 8, `doc/decisions.md`).
class NoGameSound implements GameSound {
  const NoGameSound();

  @override
  void keyTick() {}

  @override
  void correct(int streak) {}

  @override
  void wrong() {}

  @override
  void levelUp() {}
}
