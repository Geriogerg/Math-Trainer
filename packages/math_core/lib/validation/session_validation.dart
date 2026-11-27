import '../leveling/level.dart';
import '../leveling/level_updates.dart';
import '../leveling/rules_version.dart';
import '../models/game_setup.dart';
import '../models/answer_result.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../models/session_kind.dart';
import '../persistence/exercise_codec.dart';
import '../persistence/level_cache_entry.dart';
import '../replay/session_replay.dart';
import '../persistence/persisted_session.dart';
import '../persistence/session_repository.dart';
import '../sync/session_upload.dart';
import '../weak_spots/history.dart';
import '../weak_spots/item.dart';

/// What the server knows of a player before an upload: its own level cache
/// (written only by accepted sessions), the time of the last accepted
/// session, and whether any accepted session was completed.
class ServerPlayerState {
  const ServerPlayerState({
    this.levels = const {},
    this.lastSessionAt,
    this.lastSessionEndsAt,
    this.hasCompletedSession = false,
  });

  static const empty = ServerPlayerState();

  final Map<ExerciseType, LevelCacheEntry> levels;
  final DateTime? lastSessionAt;

  /// When the player's latest accepted session ended: its `createdAt`, the
  /// moment the app stored it (Phase 6a; read as its start until the 6a
  /// close-out). `null`: none yet, or a server that did not record it.
  final DateTime? lastSessionEndsAt;
  final bool hasCompletedSession;
}

/// Why an upload was refused. The names are stored server-side and sent to
/// the app: renaming one breaks both.
enum RejectionReason {
  /// The session belongs to another player than the caller.
  wrongPlayer,

  /// Timestamped after the moment the server received it (beyond clock
  /// skew). A session's `createdAt` is its end, so this also refuses one
  /// received sooner than its own answers took (Phase 6a).
  futureTimestamp,

  /// Older than the player's last accepted session: uploads come in order.
  outOfOrder,

  /// No answer, or more answers than planned questions.
  badAnswerCount,

  /// Lacks what a replay needs (`SessionNotReplayable`).
  notReplayable,

  /// A question differs from what (seed, stored config) regenerates.
  questionMismatch,

  /// An answer's claimed correctness differs from the recomputed one.
  correctnessMismatch,

  /// A response time outside [0, 30 s] (15 s before the Redesign phase).
  badElapsed,

  /// The session's frozen levels are not the server's current levels (or
  /// the placement's starting levels): played from a level the server
  /// never gave — another device, or history from before uploads.
  levelsMismatch,

  /// A completed placement after a completed session. No longer produced:
  /// placements were removed with rules v1 (kept, the name is stored).
  placementAfterGames,

  /// A type placement on an already-played operation. No longer produced,
  /// like [placementAfterGames].
  typeAlreadyPlayed,

  /// Played under rules that no longer exist (rules v1, before the Levels
  /// phase's transition): its levels are gone, so it can move nothing
  /// (`doc/levels.md`, section 4; `doc/decisions.md`).
  rulesRetired,
}

/// Something worth a human look that is not a reason to refuse (plan 6.4:
/// implausible timing is flagged, never auto-banned).
enum ValidationFlag {
  /// Several right multi-digit answers under 300 ms.
  implausiblyFast,

  /// Unnaturally flat response times over many right answers.
  flatTimes,

  /// A Levelling game re-asked weak spots the player's accepted history
  /// does not make due (Phase 4 close-out). The game is still accepted for
  /// levels — its weak spots are from the player's tier either way — but
  /// worth a look before duels are ranked on it (plan v3.6).
  weakSpotsNotDue,

  /// A duel run the player never sent (Phase 7 close-out): recorded as a
  /// loss 24 hours after the duel started, from the answers the server had
  /// received. Kept out of the duel pool (never a run to race), never
  /// reviewed.
  abandoned,

  /// A duel run the server wrote in place of one that did not replay
  /// (plan v3.9, Phase 6a): for a duel's second player a refused run is a
  /// loss, recorded from what the server had received. Like [abandoned]:
  /// never in the pool, never reviewed (the reason is in
  /// `duel_run_rejections`).
  forfeited,

  /// A session created before the player's previous one could have ended
  /// (plan v3.9, Phase 6a; review M5): two games at once, or timestamps
  /// that were written, not lived. Accepted — a phone's clock set back
  /// between two games does it honestly — and listed for the owner
  /// (`owner_dashboard.moderation_evidence`).
  overlapsPrevious,
}

sealed class ValidationResult {
  const ValidationResult();
}

final class Accepted extends ValidationResult {
  const Accepted({
    required this.completed,
    required this.levelUpdates,
    required this.flags,
    required this.newState,
  });

  /// Played to its last question. An interrupted session is kept but moves
  /// no level.
  final bool completed;

  final Map<ExerciseType, LevelCacheEntry> levelUpdates;
  final Set<ValidationFlag> flags;

  /// The player's state once this session is applied.
  final ServerPlayerState newState;
}

final class Rejected extends ValidationResult {
  const Rejected(this.reason, this.detail);

  final RejectionReason reason;

  /// For the logs and the flag record; never shown to players.
  final String detail;
}

/// Tolerated clock skew between a phone and the server.
const maxClockSkew = Duration(minutes: 5);

/// The longest a question can take: the per-question timeout.
const maxElapsedMs = 30000;

/// How far before the previous session's end a session may start without
/// being flagged [ValidationFlag.overlapsPrevious]: rounding, not play.
const overlapTolerance = Duration(seconds: 2);

/// The server's check of one uploaded session (plan 6.4): regenerate every
/// question from the seed and the stored config with the same core, recheck
/// every answer, replay the level update from the server's own state.
/// Pure: the server reads the state, calls this, writes the result.
///
/// [history]: the player's accepted sessions, oldest first — read by the
/// server only for a Levelling game holding weak spots
/// ([needsUploadHistory]); each weak spot must be due in the schedule
/// rebuilt from it (`scheduleFromHistory`), or the game is flagged
/// [ValidationFlag.weakSpotsNotDue]. `null`: not checked.
ValidationResult validateSessionUpload({
  required SessionUpload upload,
  required String callerId,
  required ServerPlayerState state,
  required DateTime receivedAt,
  List<StoredGame>? history,
}) {
  final session = upload.session;
  final answers = upload.answers;

  if (session.playerId != callerId) {
    return const Rejected(RejectionReason.wrongPlayer, 'player id');
  }
  switch (session.rulesVersion) {
    case RulesVersion.v1:
      return const Rejected(RejectionReason.rulesRetired, 'rules v1');
    case RulesVersion.v2:
    case RulesVersion.v3:
    case RulesVersion.v4:
    case RulesVersion.v5:
    case RulesVersion.v6:
    case RulesVersion.v7:
    case RulesVersion.v8:
    case RulesVersion.v9:
      break;
  }
  if (session.createdAt.isAfter(receivedAt.add(maxClockSkew))) {
    return Rejected(
      RejectionReason.futureTimestamp,
      '${session.createdAt} > $receivedAt',
    );
  }
  final last = state.lastSessionAt;
  if (last != null && session.createdAt.isBefore(last)) {
    return Rejected(RejectionReason.outOfOrder, '${session.createdAt} < $last');
  }
  if (answers.isEmpty || answers.length > session.exerciseCount) {
    return Rejected(
      RejectionReason.badAnswerCount,
      '${answers.length} for ${session.exerciseCount}',
    );
  }
  var playedMs = 0;
  for (final (i, a) in answers.indexed) {
    if (a.elapsedMs < 0 || a.elapsedMs > maxElapsedMs) {
      return Rejected(RejectionReason.badElapsed, 'answer $i: ${a.elapsedMs}');
    }
    playedMs += a.elapsedMs;
  }
  // A session's `createdAt` is its **end**: the app stores a game when its
  // last answer is given or when it is left (`SessionController`). Its
  // answers took [playedMs] before that, so it started by `createdAt −
  // playedMs` at the latest (the pauses after a wrong answer are not in
  // the answers' times). "Received sooner than its own answers took" is the
  // `createdAt` check above. Phase 6a read `createdAt` as the start and
  // refused, as ending after it was received, every game with more than
  // five minutes of answering sent at once (fixed at the 6a close-out).
  final endsAt = session.createdAt;
  final startedBy = endsAt.subtract(Duration(milliseconds: playedMs));
  final previousEnd = state.lastSessionEndsAt;
  final overlaps =
      previousEnd != null &&
      startedBy.isBefore(previousEnd.subtract(overlapTolerance));

  // Every question regenerated from what the session stores.
  final List<Exercise> questions;
  try {
    questions = replaySessionQuestions(session, answers.length);
  } on SessionNotReplayable catch (e) {
    return Rejected(RejectionReason.notReplayable, e.reason);
  }
  final outcomes = <AnswerResult>[];
  for (final (i, answer) in answers.indexed) {
    final question = questions[i];
    final described = describeExerciseForStorage(question);
    if (described.exerciseType != answer.exerciseType ||
        described.operationType != answer.operationType ||
        !_sameOperands(described.operands, answer.operands)) {
      return Rejected(RejectionReason.questionMismatch, 'question $i');
    }
    final isCorrect = question.isCorrectAnswer(answer.submittedValue);
    if (isCorrect != answer.isCorrect) {
      return Rejected(RejectionReason.correctnessMismatch, 'answer $i');
    }
    outcomes.add(
      AnswerResult(
        exercise: question,
        submittedValue: answer.submittedValue,
        isCorrect: isCorrect,
        elapsedMs: answer.elapsedMs,
        answeredAt: answer.createdAt,
      ),
    );
  }

  final completed = answers.length == session.exerciseCount;
  final Map<ExerciseType, LevelCacheEntry> updates;
  switch (session.kind) {
    case SessionKind.game:
      // The chain: a game must start from the levels the server holds, 0
      // for an operation never played.
      for (final type in session.enabledTypes) {
        final expected = state.levels[type]?.level ?? Level.zero;
        if (session.levels[type] != expected) {
          return Rejected(
            RejectionReason.levelsMismatch,
            '${type.name}: ${session.levels[type]?.hundredths} '
            '!= ${expected.hundredths}',
          );
        }
      }
      updates = completed
          ? gameLevelUpdates(
              outcomes: outcomes,
              frozenLevels: session.levels,
              priorLevels: state.levels,
              now: session.createdAt,
              rulesVersion: session.rulesVersion,
            )
          : const {};
    case SessionKind.training:
      // A fixed difficulty, the same for every operation; never a level
      // update, whatever the levels the server holds.
      final difficulties = {
        for (final type in session.enabledTypes)
          switch (session.levels[type]) {
            final level? => TrainingDifficulty.ofLevel(level),
            null => null,
          },
      };
      if (difficulties.length != 1 || difficulties.single == null) {
        return Rejected(
          RejectionReason.levelsMismatch,
          'training levels ${session.levels.values}',
        );
      }
      updates = const {};
    case SessionKind.weakSpots:
    case SessionKind.drill:
      // Practice (Phase 4): replayed and checked above, never a level
      // update, whatever the levels it was played at.
      updates = const {};
    case SessionKind.placementV1:
    case SessionKind.placementV2:
    case SessionKind.typePlacementV3:
      // The replay above already refused it (no placement under rules v2).
      return const Rejected(RejectionReason.notReplayable, 'placement');
  }

  return Accepted(
    completed: completed,
    levelUpdates: updates,
    flags: {
      ...timingFlags(outcomes),
      if (overlaps) ValidationFlag.overlapsPrevious,
      if (history != null &&
          needsUploadHistory(session) &&
          weakSpotsNotDue(session, history).isNotEmpty)
        ValidationFlag.weakSpotsNotDue,
    },
    newState: ServerPlayerState(
      levels: {...state.levels, ...updates},
      lastSessionAt: session.createdAt,
      lastSessionEndsAt: previousEnd != null && previousEnd.isAfter(endsAt)
          ? previousEnd
          : endsAt,
      hasCompletedSession: state.hasCompletedSession || completed,
    ),
  );
}

/// Whether checking [session] needs the player's accepted history: a
/// Levelling game holding weak spots (Phase 4 close-out).
bool needsUploadHistory(PersistedSession session) =>
    session.kind == SessionKind.game && session.weakSpots.isNotEmpty;

/// [session]'s weak spots that are not due in the schedule rebuilt from
/// [history] (the player's earlier accepted sessions); empty when all are.
List<Item> weakSpotsNotDue(PersistedSession session, List<StoredGame> history) {
  final schedule = scheduleFromHistory(history);
  return [
    for (final item in session.weakSpots)
      if (!schedule.isDue(item)) item,
  ];
}

/// Implausible timing (plan 6.4): flagged for review, never a rejection.
Set<ValidationFlag> timingFlags(List<AnswerResult> outcomes) {
  final right = outcomes.where((o) => o.isCorrect).toList();
  final fastMultiDigit = right
      .where((o) => o.elapsedMs < 300 && o.exercise.correctAnswer.abs() >= 10)
      .length;
  var flat = false;
  if (right.length >= 8) {
    final times = [for (final o in right) o.elapsedMs];
    final mean = times.fold<int>(0, (s, t) => s + t) / times.length;
    final variance =
        times.fold<double>(0, (s, t) => s + (t - mean) * (t - mean)) /
        times.length;
    // Standard deviation under 40 ms: no human types that evenly.
    flat = variance < 40 * 40;
  }
  return {
    if (fastMultiDigit >= 2) ValidationFlag.implausiblyFast,
    if (flat) ValidationFlag.flatTimes,
  };
}

bool _sameOperands(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}
