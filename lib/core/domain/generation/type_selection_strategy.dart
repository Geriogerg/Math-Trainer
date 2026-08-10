import '../models/exercise_type.dart';

/// Décide la séquence des types d'exercice d'une session — point
/// d'extension entre le solo (rotation par dette, dépend de l'historique du
/// joueur) et le duel futur (quotas fixes, indépendants de l'historique
/// pour que deux joueurs reçoivent la même séquence à `(seed, config)` égal
/// sans partager leurs données locales). Voir `doc/decisions.md`.
abstract class TypeSelectionStrategy {
  /// [sortedEnabledTypes] est déjà trié par `.index` (jamais tiré
  /// directement sur un `Set`). La longueur du résultat fixe le nombre de
  /// questions de la session.
  List<ExerciseType> sequenceFor(List<ExerciseType> sortedEnabledTypes);
}
