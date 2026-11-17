/// Fournit l'identifiant UUID local de l'appareil — le `playerId` d'avant le
/// passage aux comptes. Ne sert plus qu'à retrouver ces anciennes parties
/// pour les rattacher au premier compte connecté (`environmentForAccount`) ;
/// l'implémentation concrète (shared_preferences) vit dans la couche
/// d'infrastructure, jamais dans le domaine.
abstract class LocalPlayerIdProvider {
  Future<String> currentPlayerId();
}
