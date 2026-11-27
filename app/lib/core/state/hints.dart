/// One-time explanations a newcomer sees once (Phase 6b commit 4, review
/// M16): the first-run card on Home, the rules of Get the count and of
/// Chain operations on their first open. Remembered on the device.
abstract interface class HintsStore {
  Future<bool> seen(Hint hint);

  Future<void> markSeen(Hint hint);
}

/// The stored names: never rename one, or the hint shows again.
enum Hint { firstRun, countRules, chainRules }
