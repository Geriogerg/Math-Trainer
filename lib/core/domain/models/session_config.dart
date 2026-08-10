import 'exercise_type.dart';

class SessionConfig {
  const SessionConfig({
    required this.seed,
    required this.enabledTypes,
    required this.exerciseCount,
    required this.levels,
  });

  final int seed;
  final Set<ExerciseType> enabledTypes;
  final int exerciseCount;

  /// Niveaux par opération figés au début de la session — jamais recalculés
  /// en cours de route (sinon le mode duel ne peut pas être revalidé côté
  /// serveur, voir `doc/decisions.md`).
  final Map<ExerciseType, int> levels;
}
