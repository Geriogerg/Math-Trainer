import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/leveling/main_level.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/sync/session_upload.dart';

/// The Levelling game being played on this device, kept after every answer
/// (Phase 6b commit 2; `doc/levels.md` v1.6, "Quitting never pays"): a game
/// left by closing the tab still counts. One game at a time — the last one
/// started; cleared once the game is stored.
abstract interface class UnfinishedGameStore {
  Future<void> save(SessionUpload game);

  /// The game kept, or `null`; throws [FormatException] for one that cannot
  /// be read.
  Future<SessionUpload?> load();

  Future<void> clear();
}

/// At start: a game the app could not finish storing — the tab closed
/// mid-game, or the app closed after its end-of-game write failed — stored
/// now, as a game left at its last answer. Under rules that count a quit
/// (v9) its unanswered questions are timeouts ([SessionLevelUpdates],
/// with the game's planned order); under older rules, or for a game whose
/// [levelUpdates] are none (Training), it moves no level. Returns whether a
/// game was stored.
///
/// Nothing is stored twice: a game whose session is already in [repository]
/// (its write landed, the clear did not) is only cleared. A kept game that
/// cannot be read is dropped. A failure to store leaves it kept, for the
/// next start.
Future<bool> recoverUnfinishedGame({
  required UnfinishedGameStore store,
  required SessionRepository repository,
  SessionLevelUpdates levelUpdates = const LevelCacheOrchestrator(),
}) async {
  final SessionUpload? game;
  try {
    game = await store.load();
  } on FormatException {
    await store.clear();
    return false;
  }
  if (game == null) return false;
  final session = game.session;
  if (game.answers.isEmpty ||
      (await repository.answersForSession(session.id)).isNotEmpty) {
    await store.clear();
    return false;
  }
  final outcomes = [
    for (final a in game.answers)
      AnswerResult(
        exercise: exerciseFromStorage(
          exerciseType: a.exerciseType,
          operationType: a.operationType,
          operands: a.operands,
        ),
        submittedValue: a.submittedValue,
        isCorrect: a.isCorrect,
        elapsedMs: a.elapsedMs,
        answeredAt: a.createdAt,
        inputDevice: a.inputDevice,
      ),
  ];
  final updates = session.rulesVersion.quitCounts
      ? await levelUpdates.computeUpdates(
          outcomes: outcomes,
          frozenLevels: session.levels,
          repository: repository,
          playerId: session.playerId,
          now: session.createdAt,
          rulesVersion: session.rulesVersion,
          typeSequence:
              session.typeSequence ??
              [for (final o in outcomes) o.exercise.type],
        )
      : const <Never, Never>{};
  final before = await repository.currentLevels(session.playerId);
  await repository.recordSession(
    session: session.copyWith(
      overallLevelAfter: mainLevel({...before, ...updates}),
    ),
    answers: game.answers,
    levelUpdates: updates,
  );
  await store.clear();
  return true;
}
