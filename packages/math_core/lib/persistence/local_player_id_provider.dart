/// Provides the device's local UUID — the `playerId` from before accounts.
/// Only used now to find those older games and hand them to the first
/// account that signs in (`environmentForAccount`); the concrete
/// implementation (shared_preferences) lives in the infrastructure layer,
/// never in the domain.
abstract class LocalPlayerIdProvider {
  Future<String> currentPlayerId();
}
