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
  const PlacementLevelOrchestrator({this.rules = placementRulesV1});

  final PlacementRules rules;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, Level> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async {
    final levels = placementLevels([
      for (final o in outcomes)
        (isCorrect: o.isCorrect, elapsedMs: o.elapsedMs),
    ], rules);
    return levels.map(
      (type, level) => MapEntry(
        type,
        LevelCacheEntry(
          level: level,
          sessionsPlayed: rules.sessionsPlayedAfter,
          updatedAt: now,
        ),
      ),
    );
  }
}
