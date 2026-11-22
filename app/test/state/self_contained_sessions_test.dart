import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';
import 'package:math_trainer/infrastructure/persistence/database.dart';
import 'package:math_trainer/infrastructure/persistence/sqflite_session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// Plan, Phase 2 commit 1: "a test replays every stored session in
/// isolation". Real sessions, built by the app's own builders and stored in
/// a real SQLite database; then each stored session is replayed from what
/// it stores alone — no history, no level cache — and must give back the
/// exact questions its answers were given to.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('every stored session replays in isolation', () async {
    final db = await openMathTrainerDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final repository = SqfliteSessionRepository(db);
    final environment = AppEnvironment(
      repository: repository,
      playerId: 'player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );

    /// Right answers only: a wrong one starts a real 1 s correction timer.
    /// The placement still adapts (every pass moves a staircase up).
    Future<void> play(SessionController controller, {int? stopAfter}) async {
      controller.start();
      var answered = 0;
      while (controller.state.status == SessionStatus.inProgress) {
        if (stopAfter != null && answered == stopAfter) {
          controller.abandon();
          break;
        }
        controller.submitAnswer(
          controller.state.currentExercise!.correctAnswer,
        );
        answered++;
      }
      await controller.pendingPersistence;
      controller.dispose();
    }

    await play(buildPlacementController(environment));
    final all = ExerciseType.values.toSet();
    for (final types in [
      {ExerciseType.addition, ExerciseType.subtraction},
      all,
      {ExerciseType.multiplication, ExerciseType.division, ExerciseType.power},
      all,
      all,
    ]) {
      await play(await buildSessionController(environment, types));
    }
    // Interrupted after 5 answers: replays its answered prefix.
    await play(await buildSessionController(environment, all), stopAfter: 5);

    final sessions = await repository.recentSessions('player', limit: 100);
    expect(sessions, hasLength(7));
    expect(
      sessions.where((s) => s.kind == SessionKind.placementV2),
      hasLength(1),
    );

    for (final session in sessions) {
      expect(session.typeSequence, hasLength(session.exerciseCount));
      final answers = await repository.answersForSession(session.id);
      final questions = replaySessionQuestions(session, [
        for (final a in answers)
          (isCorrect: a.isCorrect, elapsedMs: a.elapsedMs),
      ]);
      expect(questions, hasLength(answers.length));
      for (var i = 0; i < answers.length; i++) {
        final described = describeExerciseForStorage(questions[i]);
        final where = 'session ${session.id}, question $i';
        expect(
          described.operationType,
          answers[i].operationType,
          reason: where,
        );
        expect(described.operands, equals(answers[i].operands), reason: where);
      }
    }

    // Every game played the default plan: exactly 10 questions of each
    // selected operation (Redesign phase commit 2).
    for (final s in sessions.where((s) => s.kind == SessionKind.game)) {
      for (final type in s.enabledTypes) {
        expect(s.typeSequence!.where((t) => t == type).length, 10);
      }
    }
  });
}
