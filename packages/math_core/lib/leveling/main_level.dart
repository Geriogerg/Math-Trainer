import '../models/exercise_type.dart';
import '../models/session_kind.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/persisted_session.dart';
import 'level.dart';

/// The main level (plan v2.9): the mean of the four **basic** operations,
/// one never played counting at 0 (`doc/levels.md`: everyone starts there)
/// rather than left out of the mean. Advanced operations never
/// count in it: each has its own level and board. The same rule ranks the
/// main board server-side (`leaderboard_rows`, board `overall`).
///
/// In the domain, not the presentation: it is also the value stored with
/// each session (`PersistedSession.overallLevelAfter`), hence a data rule —
/// changing it means recomputing the stored values ([mainLevelsAfter]).
///
/// In level units (37.42, not 3742). Display only — never a ranking value.
double mainLevel(Map<ExerciseType, LevelCacheEntry> levels) => mainLevelOf({
  for (final MapEntry(:key, :value) in levels.entries) key: value.level,
});

/// [mainLevel] over bare levels.
double mainLevelOf(Map<ExerciseType, Level> levels) {
  final basics = ExerciseFamily.basics.types;
  var sum = 0;
  for (final type in basics) {
    sum += (levels[type] ?? Level.zero).hundredths;
  }
  return sum / basics.length / 100;
}

/// One stored session as [mainLevelsAfter] reads it: [completed] is
/// "played to its last question" — only then could it move a level.
typedef SessionLevelTrace = ({PersistedSession session, bool completed});

/// The main level right after each of a player's [sessions], rebuilt from
/// the player's [current] levels by walking back through history: a
/// completed game started from its frozen levels, so undoing it restores
/// them; a completed placement created its types' levels, so undoing it
/// removes them; an interrupted session or a Training game moved nothing. Used once, by the
/// app's schema v9, when the main level replaced the seven-type overall
/// level (Redesign phase commit 1): the Profile curve stays on one scale.
///
/// Approximate where the history is not the whole story (levels adopted
/// from the server after a game on another device): those points keep the
/// local history's view. Display only.
Map<String, double> mainLevelsAfter({
  required List<SessionLevelTrace> sessions,
  required Map<ExerciseType, Level> current,
}) {
  final ordered = [...sessions]
    ..sort((a, b) {
      final byTime = b.session.createdAt.compareTo(a.session.createdAt);
      return byTime != 0 ? byTime : b.session.id.compareTo(a.session.id);
    });
  final levels = Map<ExerciseType, Level>.of(current);
  final after = <String, double>{};
  for (final (:session, :completed) in ordered) {
    after[session.id] = mainLevelOf(levels);
    if (!completed) continue;
    switch (session.kind) {
      case SessionKind.game:
        for (final type in session.enabledTypes) {
          final frozen = session.levels[type];
          if (frozen != null) levels[type] = frozen;
        }
      case SessionKind.placementV1:
      case SessionKind.placementV2:
      case SessionKind.typePlacementV3:
        session.enabledTypes.forEach(levels.remove);
      case SessionKind.training:
      case SessionKind.weakSpots:
      case SessionKind.drill:
        // Never moves a level.
        break;
    }
  }
  return after;
}
