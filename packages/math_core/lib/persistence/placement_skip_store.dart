/// Remembers, per player, that the placement offer was skipped (owner, end
/// of Phase 1): Play no longer offers it; Profile still does while the
/// player has no completed session. Concrete implementation in
/// `infrastructure/` (rule 3).
abstract class PlacementSkipStore {
  Future<bool> hasSkipped(String playerId);

  Future<void> markSkipped(String playerId);
}
