import '../models/exercise.dart';

/// Fournit la séquence d'exercices d'une session. La séparation d'avec
/// `ExerciseGenerator` est le point d'extension pour le duel : une future
/// implémentation réseau pourra remplacer `LocalExerciseSource` sans changer
/// `SessionController` ni l'UI.
abstract class ExerciseSource {
  Exercise next();
}
