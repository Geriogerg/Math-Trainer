import '../leveling/level.dart';
import '../leveling/level_cache_orchestrator.dart';
import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/session_repository.dart';
import 'placement.dart';

/// Level cache updates of a **complete** placement: the four basic
/// operations get the staircases' final levels (`placementLevels`), with
/// `sessionsPlayed` = [PlacementRules.sessionsPlayedAfter] so the next games
/// keep the calibration boost. Powers, roots and percentages are left
/// alone (plan: they start where they do today). Called only for a
/// finished session — an interrupted placement sets nothing.
class PlacementLevelOrchestrator implements SessionLevelUpdates {
  const PlacementLevelOrchestrator({
    this.rules = currentPlacementRules,
    this.sequence,
  });

  final PlacementRules rules;

  /// A type placement's rotation; `null` for the placement test.
  final List<ExerciseType>? sequence;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, Level> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async => placementLevelUpdates(
    outcomes: outcomes,
    rules: rules,
    now: now,
    sequence: sequence,
  );
}

/// Level cache entries of a **completed** placement — pure, shared with
/// the server's validation: the staircases' final levels
/// (`placementLevels`), `sessionsPlayed` from the rules.
Map<ExerciseType, LevelCacheEntry> placementLevelUpdates({
  required List<AnswerResult> outcomes,
  required PlacementRules rules,
  required DateTime now,
  List<ExerciseType>? sequence,
}) =>
    placementLevels(
      [
        for (final o in outcomes)
          (isCorrect: o.isCorrect, elapsedMs: o.elapsedMs),
      ],
      rules,
      sequence: sequence,
    ).map(
      (type, level) => MapEntry(
        type,
        LevelCacheEntry(
          level: level,
          sessionsPlayed: rules.sessionsPlayedAfter,
          updatedAt: now,
        ),
      ),
    );
