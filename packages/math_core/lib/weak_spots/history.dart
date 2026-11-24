import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise.dart';
import '../patterns/pattern_family.dart';
import '../persistence/exercise_codec.dart';
import '../persistence/persisted_session.dart';
import '../persistence/session_repository.dart';
import '../replay/session_replay.dart';
import '../tiers/fluent_time.dart';
import '../tiers/tier_content.dart';
import 'facts.dart';
import 'item.dart';
import 'item_of.dart';
import 'scheduler.dart';

/// The time under which a correct answer to [item] is fluent for the
/// scheduler (`doc/decisions.md`, "Phase 4"): a fact's own — its home
/// tier's fluent time under the current rules (7 × 8: T1's 4 s, wherever it
/// is asked); a skill's — the fluent time of the level it was drawn at
/// ([drawnAt]) under the game's [rules] (the current ones for a retired
/// game).
int itemFluentMs(
  Item item, {
  required Level drawnAt,
  required RulesVersion rules,
}) => switch (item) {
  FactItem() => fluentTimeMs(
    item.type,
    Level.whole(10 * homeTier(item)!.index),
    RulesVersion.current,
  ),
  SkillItem() => fluentTimeMs(
    item.type,
    drawnAt,
    rules.retired ? RulesVersion.current : rules,
  ),
};

/// [game]'s answers to tracked items, graded, in order. An answer whose
/// question is no item (a long sum, a split factor) is left out. The
/// pattern families come from replaying the game; a game that cannot be
/// replayed (retired rules) has standard questions only.
List<GradedAnswer> gradedAnswersOf(StoredGame game) {
  final (:session, :answers) = game;
  final exercises = [
    for (final a in answers)
      exerciseFromStorage(
        exerciseType: a.exerciseType,
        operationType: a.operationType,
        operands: a.operands,
      ),
  ];
  final families = _familiesOf(session, exercises);
  final rules = session.rulesVersion;
  return [
    for (final (i, answer) in answers.indexed)
      if (itemOf(exercises[i], family: families[i]) case final item?)
        (
          item: item,
          grade: !answer.isCorrect
              ? Grade.miss
              : answer.elapsedMs <=
                    itemFluentMs(
                      item,
                      drawnAt: session.levels[item.type] ?? Level.zero,
                      rules: rules,
                    )
              ? Grade.fluent
              : Grade.slow,
        ),
  ];
}

/// The schedule after [games], replayed in their own time order (ties by
/// id: two devices' clocks may agree to the millisecond).
WeakSpotSchedule scheduleFromHistory(Iterable<StoredGame> games) {
  final ordered = games.toList()
    ..sort((a, b) {
      final byTime = a.session.createdAt.compareTo(b.session.createdAt);
      return byTime != 0 ? byTime : a.session.id.compareTo(b.session.id);
    });
  return WeakSpotSchedule.replay(ordered.map(gradedAnswersOf));
}

/// Each answered question's family, from the replay — trusted only where
/// the replay asks the very question stored (a family is never guessed).
List<PatternFamily?> _familiesOf(
  PersistedSession session,
  List<Exercise> asked,
) {
  final none = List<PatternFamily?>.filled(asked.length, null);
  if (asked.isEmpty) return none;
  final List<TierQuestion> replay;
  try {
    replay = replaySession(session, asked.length);
  } on SessionNotReplayable {
    return none;
  }
  return [
    for (final (i, q) in replay.indexed)
      q.exercise == asked[i] ? q.family : null,
  ];
}
