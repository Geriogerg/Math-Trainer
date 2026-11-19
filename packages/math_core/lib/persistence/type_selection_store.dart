import '../models/exercise_type.dart';

/// Remembers the type selection between app launches — concrete
/// implementation (shared_preferences) in `infrastructure/`, never in the
/// domain (rule 3).
abstract class TypeSelectionStore {
  /// `null`: never stored, the caller applies its own default. An empty set
  /// stored explicitly (the player unticked everything) is distinct from
  /// `null` and must be respected as is.
  Future<Set<ExerciseType>?> load();

  Future<void> save(Set<ExerciseType> types);
}
