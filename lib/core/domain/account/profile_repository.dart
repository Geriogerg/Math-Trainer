import 'player_profile.dart';

/// The player's public profile (player name) — separate from
/// `AccountRepository` (identity/authentication). Concrete implementation
/// (Supabase) in `infrastructure/backend/`, never in the domain (rule 3).
abstract class ProfileRepository {
  /// `displayName == null` if the player has never chosen a name (not an
  /// error). Throws an `Exception` if nobody is signed in or on a network
  /// failure.
  Future<PlayerProfile> currentProfile();

  /// Creates the profile if it does not exist yet. Throws an `Exception` on
  /// failure (network unavailable, nobody signed in).
  Future<void> updateDisplayName(String displayName);
}
