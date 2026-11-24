import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/session_state.dart';
import 'package:math_trainer/infrastructure/persistence/database.dart';
import 'package:math_trainer/infrastructure/persistence/sqflite_session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// Phase 4 commit 3 (rules v7): a fact missed in one game comes back in the
/// next Levelling game of its operation at that tier, stored with it, and
/// the stored game replays alone.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'a missed 3 × 4 is re-asked in the next game, stored, replayed',
    () async {
      final db = await openMathTrainerDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      final repository = SqfliteSessionRepository(db);
      final environment = AppEnvironment(
        repository: repository,
        playerId: 'player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );
      // A past game at level 0 (T0) whose only answer missed 3 × 4.
      final missed = ArithmeticExercise(
        operandA: 3,
        operandB: 4,
        operationType: OperationType.multiplication,
      );
      final past = PersistedSession(
        id: 'past',
        playerId: 'player',
        seed: 1,
        enabledTypes: {ExerciseType.multiplication},
        exerciseCount: 4,
        totalScore: 0,
        levels: {ExerciseType.multiplication: Level.zero},
        createdAt: DateTime.utc(2026, 11, 24),
        typeSequence: List.filled(4, ExerciseType.multiplication),
        rulesVersion: RulesVersion.v7,
      );
      final d = describeExerciseForStorage(missed);
      await repository.recordSession(
        session: past,
        answers: [
          PersistedAnswer(
            id: 'a',
            sessionId: 'past',
            exerciseType: d.exerciseType,
            operationType: d.operationType,
            operands: d.operands,
            submittedValue: 11,
            isCorrect: false,
            elapsedMs: 3000,
            createdAt: past.createdAt,
          ),
        ],
        levelUpdates: const {},
      );
      final fact = factOf(missed)!;
      expect((await loadWeakSpotSchedule(environment)).due, [fact]);

      final controller = await buildSessionController(environment, {
        ExerciseType.multiplication,
      }, setup: GameSetup(questionsPerOperation: 10));
      expect(controller.config.weakSpots, <Item>[fact]);
      controller.start();
      final asked = <Exercise>[];
      while (controller.state.status == SessionStatus.inProgress) {
        final q = controller.state.currentExercise!;
        asked.add(q);
        controller.submitAnswer(q.correctAnswer);
      }
      await controller.pendingPersistence;
      controller.dispose();
      expect(asked.where((q) => factOf(q) == fact), isNotEmpty);

      final games = await repository.storedGames('player');
      expect(games.map((g) => g.session.id).first, 'past');
      final stored = games.last.session;
      expect(stored.weakSpots, [fact]);
      expect(replaySessionQuestions(stored, 10), asked);
      // Answered fluently? Not timed here; at least no longer box 1 now.
      final schedule = await loadWeakSpotSchedule(environment);
      expect(schedule.games, 2);
    },
  );

  test('the Weak spots game: the due items, practice, stored and replayed '
      'alone', () async {
    final db = await openMathTrainerDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    final repository = SqfliteSessionRepository(db);
    final environment = AppEnvironment(
      repository: repository,
      playerId: 'player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );
    final missed = ArithmeticExercise(
      operandA: 3,
      operandB: 4,
      operationType: OperationType.multiplication,
    );
    final d = describeExerciseForStorage(missed);
    final past = PersistedSession(
      id: 'past',
      playerId: 'player',
      seed: 1,
      enabledTypes: {ExerciseType.multiplication},
      exerciseCount: 4,
      totalScore: 0,
      levels: {ExerciseType.multiplication: Level.zero},
      createdAt: DateTime.utc(2026, 11, 24),
      rulesVersion: RulesVersion.v7,
    );
    await repository.recordSession(
      session: past,
      answers: [
        PersistedAnswer(
          id: 'a',
          sessionId: 'past',
          exerciseType: d.exerciseType,
          operationType: d.operationType,
          operands: d.operands,
          submittedValue: 11,
          isCorrect: false,
          elapsedMs: 3000,
          createdAt: past.createdAt,
        ),
      ],
      levelUpdates: const {},
    );
    final items = await weakSpotsGameItems(environment);
    expect(items, [factOf(missed)]);
    final controller = await buildWeakSpotsController(environment, items);
    expect(controller.config.kind, SessionKind.weakSpots);
    controller.start();
    final q = controller.state.currentExercise!;
    expect(factOf(q), factOf(missed));
    controller.submitAnswer(q.correctAnswer);
    await controller.pendingPersistence;
    controller.dispose();
    final stored = (await repository.storedGames('player')).last.session;
    expect(stored.kind, SessionKind.weakSpots);
    expect(stored.weakSpots, items);
    expect(replaySessionQuestions(stored, 1), [q]);
    expect(await repository.currentLevels('player'), isEmpty);
  });
}
