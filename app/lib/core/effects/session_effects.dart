/// What a session plays besides the screen itself — haptics now, sound from
/// Phase 5 commit 4 (`doc/plan.md`, Phase 5).
///
/// **Fire and forget.** Every call returns `void` and is made *after* the
/// controller has moved on: an effect can never hold back the next
/// question (Phase 5 beta-safety rule, pinned by
/// `test/presentation/session_layout_pin_test.dart`). An implementation
/// that fails must fail silently; `SessionScreen` also guards every call.
abstract interface class SessionEffects {
  /// A key of the on-screen keypad or of a physical keyboard.
  void keyPressed();

  /// An answer was submitted; [streak] is the streak *after* it (0 when
  /// wrong).
  void answered({required bool correct, required int streak});

  /// The question's time ran out.
  void timedOut();
}

/// No effect at all: tests, and screens built without an environment.
class NoSessionEffects implements SessionEffects {
  const NoSessionEffects();

  @override
  void keyPressed() {}

  @override
  void answered({required bool correct, required int streak}) {}

  @override
  void timedOut() {}
}
