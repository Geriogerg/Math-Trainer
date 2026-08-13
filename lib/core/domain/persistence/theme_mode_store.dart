/// Deux valeurs seulement : le mode système n'est pas un choix mémorisé,
/// c'est l'état par défaut tant que rien n'a été enregistré (`load() ==
/// null`, même convention que `TypeSelectionStore`).
enum ThemeModePreference { light, dark }

/// Mémorise la bascule manuelle nuit/jour entre deux lancements de l'app —
/// implémentation concrète (shared_preferences) dans `infrastructure/`,
/// jamais dans le domaine (règle 3).
abstract class ThemeModeStore {
  /// `null` : jamais choisi explicitement, l'appelant retombe sur le thème système.
  Future<ThemeModePreference?> load();

  Future<void> save(ThemeModePreference preference);
}
