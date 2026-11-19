import '../leveling/level.dart';
import 'exercise_type.dart';
import 'session_kind.dart';

class SessionConfig {
  const SessionConfig({
    required this.seed,
    required this.enabledTypes,
    required this.exerciseCount,
    required this.levels,
    this.kind = SessionKind.game,
    this.typeSequence,
  });

  final int seed;
  final Set<ExerciseType> enabledTypes;
  final int exerciseCount;

  /// Per-operation levels frozen at the start of the session — never
  /// recomputed along the way (otherwise duels cannot be revalidated
  /// server-side, see `doc/decisions.md`). In hundredths; generation reads
  /// the whole part.
  final Map<ExerciseType, Level> levels;

  /// A placement's levels move with its answers: [levels] then holds the
  /// staircases' starting levels, for the record.
  final SessionKind kind;

  /// The type of every planned question, in order — decided at the start
  /// and stored with the session, so it replays from (seed, stored config)
  /// alone (plan, Phase 2 commit 1). `null` only where no session is
  /// stored from this config (tests, the endless stream).
  final List<ExerciseType>? typeSequence;
}
