import '../leveling/level.dart';
import '../leveling/level_updater.dart';
import '../leveling/level_updates.dart';
import '../leveling/rules_version.dart';
import '../models/game_setup.dart';
import '../models/answer_result.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../models/session_kind.dart';
import '../persistence/exercise_codec.dart';
import '../persistence/level_cache_entry.dart';
import '../placement/placement.dart';
import '../placement/placement_level_orchestrator.dart';
import '../replay/session_replay.dart';
import '../sync/session_upload.dart';

/// What the server knows of a player before an upload: its own level cache
/// (written only by accepted sessions), the time of the last accepted
/// session, and whether any accepted session was completed.
class ServerPlayerState {
  const ServerPlayerState({
    this.levels = const {},
    this.lastSessionAt,
    this.hasCompletedSession = false,
  });

  static const empty = ServerPlayerState();

  final Map<ExerciseType, LevelCacheEntry> levels;
  final DateTime? lastSessionAt;
  final bool hasCompletedSession;
}

/// Why an upload was refused. The names are stored server-side and sent to
/// the app: renaming one breaks both.
enum RejectionReason {
  /// The session belongs to another player than the caller.
  wrongPlayer,

  /// Timestamped after the moment the server received it (beyond clock skew).
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

  /// A completed placement after a completed session: levels come from
  /// games from then on.
  placementAfterGames,

  /// A type placement on an operation the server already has a level for
  /// (Phase 3a commit 7): only a never-played operation is placed.
  typeAlreadyPlayed,
}

/// Something worth a human look that is not a reason to refuse (plan 6.4:
/// implausible timing is flagged, never auto-banned).
enum ValidationFlag {
  /// Several right multi-digit answers under 300 ms.
  implausiblyFast,

  /// Unnaturally flat response times over many right answers.
  flatTimes,
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

/// The server's check of one uploaded session (plan 6.4): regenerate every
/// question from the seed and the stored config with the same core, recheck
/// every answer, replay the level update from the server's own state.
/// Pure: the server reads the state, calls this, writes the result.
ValidationResult validateSessionUpload({
  required SessionUpload upload,
  required String callerId,
  required ServerPlayerState state,
  required DateTime receivedAt,
  LevelUpdater? levelUpdater,
}) {
  final session = upload.session;
  final answers = upload.answers;

  if (session.playerId != callerId) {
    return const Rejected(RejectionReason.wrongPlayer, 'player id');
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
  for (final (i, a) in answers.indexed) {
    if (a.elapsedMs < 0 || a.elapsedMs > maxElapsedMs) {
      return Rejected(RejectionReason.badElapsed, 'answer $i: ${a.elapsedMs}');
    }
  }

  // Questions and correctness, in order: a placement's question i depends
  // on the recomputed correctness of the answers before it.
  final outcomes = <AnswerResult>[];
  for (final (i, answer) in answers.indexed) {
    final Exercise question;
    try {
      question = replaySessionQuestions(session, [
        for (final o in outcomes)
          (isCorrect: o.isCorrect, elapsedMs: o.elapsedMs),
        (isCorrect: false, elapsedMs: 0), // question i ignores answer i
      ])[i];
    } on SessionNotReplayable catch (e) {
      return Rejected(RejectionReason.notReplayable, e.reason);
    }
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
      // The chain: a game must start from the levels the server holds.
      final unplayed = switch (session.rulesVersion) {
        RulesVersion.v1 => Level.floor,
        RulesVersion.v2 => Level.zero,
      };
      for (final type in session.enabledTypes) {
        final expected = state.levels[type]?.level ?? unplayed;
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
              levelUpdater: levelUpdater ?? LevelUpdater(),
              rulesVersion: session.rulesVersion,
            )
          : const {};
    case SessionKind.placementV1:
    case SessionKind.placementV2:
      final rules = placementRulesFor(session.kind);
      for (final type in placementTypes) {
        if (session.levels[type] != Level.whole(rules.startLevel)) {
          return Rejected(
            RejectionReason.levelsMismatch,
            'placement start ${type.name}',
          );
        }
      }
      if (completed && state.hasCompletedSession) {
        return const Rejected(RejectionReason.placementAfterGames, '');
      }
      updates = completed
          ? placementLevelUpdates(
              outcomes: outcomes,
              rules: rules,
              now: session.createdAt,
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
    case SessionKind.typePlacementV3:
      // Never-played operations only, each from the staircase's start.
      final rules = placementRulesFor(session.kind);
      for (final type in session.enabledTypes) {
        if (state.levels.containsKey(type)) {
          return Rejected(RejectionReason.typeAlreadyPlayed, type.name);
        }
        if (session.levels[type] != Level.whole(rules.startLevel)) {
          return Rejected(
            RejectionReason.levelsMismatch,
            'type placement start ${type.name}',
          );
        }
      }
      updates = completed
          ? placementLevelUpdates(
              outcomes: outcomes,
              rules: rules,
              now: session.createdAt,
              // Replay above already checked it against the operations.
              sequence: session.typeSequence,
            )
          : const {};
  }

  return Accepted(
    completed: completed,
    levelUpdates: updates,
    flags: timingFlags(outcomes),
    newState: ServerPlayerState(
      levels: {...state.levels, ...updates},
      lastSessionAt: session.createdAt,
      hasCompletedSession: state.hasCompletedSession || completed,
    ),
  );
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
