import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// The plan's Phase 2 exit test, "rows reproduced by replay", end to end
/// on the app's side: real sessions built by the app's own builders, then
/// the server's validation replays every upload in order, from its own
/// state only — and lands on exactly the levels the app holds.
void main() {
  test('the server, replaying the uploads, holds the app’s levels', () async {
    final repository = InMemorySessionRepository();
    final environment = AppEnvironment(
      repository: repository,
      playerId: 'player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );

    /// Right answers, and a wrong one on each session's last question —
    /// the only place a wrong answer starts no real 1 s correction timer.
    Future<void> play(SessionController controller, {int? stopAfter}) async {
      controller.start();
      var i = 0;
      while (controller.state.status == SessionStatus.inProgress) {
        if (stopAfter != null && i == stopAfter) {
          controller.abandon();
          break;
        }
        final q = controller.state.currentExercise!;
        final last = i == controller.config.exerciseCount - 1;
        controller.submitAnswer(last ? q.correctAnswer + 1 : q.correctAnswer);
        i++;
      }
      await controller.pendingPersistence;
      controller.dispose();
    }

    final all = ExerciseType.values.toSet();
    for (final types in [
      {ExerciseType.addition, ExerciseType.subtraction},
      all,
      {ExerciseType.multiplication, ExerciseType.power},
      all,
    ]) {
      await play(await buildSessionController(environment, types));
    }
    // Training in between: the server accepts it, and the chain of levels
    // goes on as if it had not been played.
    final before = await repository.currentLevels('player');
    await play(
      await buildSessionController(
        environment,
        {ExerciseType.addition, ExerciseType.division},
        setup: GameSetup(
          questionsPerOperation: 4,
          mode: GameMode.training,
          difficulty: TrainingDifficulty.hard,
        ),
      ),
    );
    final afterTraining = await repository.currentLevels('player');
    for (final type in ExerciseType.values) {
      expect(afterTraining[type]?.level, before[type]?.level, reason: '$type');
      expect(afterTraining[type]?.sessionsPlayed, before[type]?.sessionsPlayed);
    }
    final training = (await repository.recentSessions('player')).first;
    expect(training.kind, SessionKind.training);
    expect(training.levels.values.toSet(), {Level.whole(70)});
    await play(await buildSessionController(environment, all), stopAfter: 4);

    var state = ServerPlayerState.empty;
    final pending = await repository.pendingUploads('player');
    expect(pending, hasLength(6));
    for (final session in pending) {
      final upload = SessionUpload(
        session: session,
        answers: await repository.answersForSession(session.id),
      );
      final result = validateSessionUpload(
        upload: upload,
        callerId: 'player',
        state: state,
        receivedAt: DateTime.now().toUtc(),
      );
      expect(result, isA<Accepted>(), reason: 'session ${session.id}');
      state = (result as Accepted).newState;
    }

    final appLevels = await repository.currentLevels('player');
    expect(state.levels.keys, unorderedEquals(appLevels.keys));
    for (final type in appLevels.keys) {
      expect(
        state.levels[type]!.level,
        appLevels[type]!.level,
        reason: '$type',
      );
      expect(
        state.levels[type]!.sessionsPlayed,
        appLevels[type]!.sessionsPlayed,
        reason: '$type',
      );
      expect(state.levels[type]!.updatedAt, appLevels[type]!.updatedAt);
    }
  });
}
