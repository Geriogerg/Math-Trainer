import 'player_profile.dart';

/// Profil public du joueur (nom de joueur) — distinct d'`AccountRepository`
/// (identité/authentification). Implémentation concrète (Supabase) dans
/// `infrastructure/backend/`, jamais dans le domaine (règle 3).
abstract class ProfileRepository {
  /// `displayName == null` si le joueur n'a encore jamais choisi de nom (pas
  /// une erreur). Lance une `Exception` si personne n'est connecté ou en cas
  /// d'échec réseau.
  Future<PlayerProfile> currentProfile();

  /// Crée le profil s'il n'existe pas encore. Lance une `Exception` en cas
  /// d'échec (réseau indisponible, personne connecté).
  Future<void> updateDisplayName(String displayName);
}
