/// Fournit l'identifiant UUID du joueur local. Aujourd'hui, un seul profil
/// implicite par appareil ; l'implémentation concrète (shared_preferences)
/// vit dans la couche d'infrastructure, jamais dans le domaine.
abstract class LocalPlayerIdProvider {
  Future<String> currentPlayerId();
}
