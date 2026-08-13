import '../models/exercise_type.dart';

/// Mémorise la sélection de types entre deux lancements de l'app —
/// implémentation concrète (shared_preferences) dans `infrastructure/`,
/// jamais dans le domaine (règle 3).
abstract class TypeSelectionStore {
  /// `null` : jamais enregistré, l'appelant applique son propre défaut.
  /// Un ensemble vide enregistré explicitement (le joueur a tout décoché)
  /// est distinct de `null` et doit être respecté tel quel.
  Future<Set<ExerciseType>?> load();

  Future<void> save(Set<ExerciseType> types);
}
