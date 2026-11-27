import 'package:math_core/duel/duel_mode.dart';

/// One-time explanations a newcomer sees once (Phase 6b commit 4, review
/// M16): the first-run card on Home, the rules of Get the count and of
/// Chain operations on their first open; the rules of each duel mode before
/// its first rated duel (plan v4.1). Remembered on the device.
abstract interface class HintsStore {
  Future<bool> seen(Hint hint);

  Future<void> markSeen(Hint hint);
}

/// The stored names: never rename one, or the hint shows again.
enum Hint {
  firstRun,
  countRules,
  chainRules,
  duelRulesBasics,
  duelRulesAdvanced,
  duelRulesCount,
}

/// The hint that remembers [mode]'s rules were read before a rated duel.
Hint duelRulesHint(DuelMode mode) => switch (mode) {
  DuelMode.basics => Hint.duelRulesBasics,
  DuelMode.advanced => Hint.duelRulesAdvanced,
  DuelMode.count => Hint.duelRulesCount,
};
