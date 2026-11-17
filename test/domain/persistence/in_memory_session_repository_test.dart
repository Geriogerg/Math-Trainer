import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:test/test.dart';

void main() {
  PersistedSession session(String id, {required DateTime createdAt, String playerId = 'player-1'}) {
    return PersistedSession(
      id: id,
      playerId: playerId,
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 10,
      totalScore: 100,
      levels: const {},
      createdAt: createdAt,
    );
  }

  PersistedAnswer answer(
    String id,
    String sessionId, {
    String operationType = 'addition',
    int elapsedMs = 1000,
  }) {
    return PersistedAnswer(
      id: id,
      sessionId: sessionId,
      exerciseType: 'arithmetic',
      operationType: operationType,
      operands: const {'operandA': 4, 'operandB': 3},
      submittedValue: 7,
      isCorrect: true,
      elapsedMs: elapsedMs,
      createdAt: DateTime.utc(2026, 8, 8),
    );
  }

  group('InMemorySessionRepository', () {
    test('recordSession puis answersForSession retrouve exactement ce qui a été écrit', () async {
      final repository = InMemorySessionRepository();
      final s = session('session-1', createdAt: DateTime.utc(2026, 8, 8));
      final answers = [answer('answer-1', 'session-1'), answer('answer-2', 'session-1')];

      await repository.recordSession(session: s, answers: answers, levelUpdates: const {});
      final result = await repository.answersForSession('session-1');

      expect(result, equals(answers));
    });

    test('answersForSession ne retourne que les réponses de la session demandée', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
        answers: [answer('answer-1', 'session-1')],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('session-2', createdAt: DateTime.utc(2026, 8, 9)),
        answers: [answer('answer-2', 'session-2')],
        levelUpdates: const {},
      );

      final result = await repository.answersForSession('session-1');

      expect(result.map((a) => a.id), equals(['answer-1']));
    });

    test('recentSessions trie du plus récent au plus ancien et respecte la limite', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('oldest', createdAt: DateTime.utc(2026, 8, 1)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('newest', createdAt: DateTime.utc(2026, 8, 10)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('middle', createdAt: DateTime.utc(2026, 8, 5)),
        answers: const [],
        levelUpdates: const {},
      );

      final result = await repository.recentSessions('player-1', limit: 2);

      expect(result.map((s) => s.id), equals(['newest', 'middle']));
    });

    test('recentSessions ne retourne que les sessions du joueur demandé', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('a-1', createdAt: DateTime.utc(2026, 8, 1), playerId: 'player-a'),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('b-1', createdAt: DateTime.utc(2026, 8, 2), playerId: 'player-b'),
        answers: const [],
        levelUpdates: const {},
      );

      final result = await repository.recentSessions('player-a');

      expect(result.map((s) => s.id), equals(['a-1']));
    });

    test('transferPlayerData rattache sessions, réponses et niveaux au nouveau joueur', () async {
      final repository = InMemorySessionRepository();
      final entry = LevelCacheEntry(level: 42, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 8, 8));
      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8), playerId: 'device'),
        answers: [answer('answer-1', 'session-1', elapsedMs: 900)],
        levelUpdates: {ExerciseType.addition: entry},
      );

      await repository.transferPlayerData(fromPlayerId: 'device', toPlayerId: 'account');

      expect((await repository.recentSessions('account')).map((s) => (s.id, s.playerId)), [
        ('session-1', 'account'),
      ]);
      expect((await repository.currentLevels('account'))[ExerciseType.addition]?.level, 42);
      expect(await repository.averageElapsedMsByType('account'), {ExerciseType.addition: 900});
      expect(await repository.recentSessions('device'), isEmpty);
      expect(await repository.currentLevels('device'), isEmpty);
    });

    test('transferPlayerData ne fusionne jamais avec un joueur qui a déjà des données', () async {
      final repository = InMemorySessionRepository();
      final deviceLevel = LevelCacheEntry(level: 10, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 8, 8));
      final accountLevel = LevelCacheEntry(level: 80, sessionsPlayed: 3, updatedAt: DateTime.utc(2026, 8, 9));
      await repository.recordSession(
        session: session('device-1', createdAt: DateTime.utc(2026, 8, 8), playerId: 'device'),
        answers: const [],
        levelUpdates: {ExerciseType.addition: deviceLevel},
      );
      await repository.recordSession(
        session: session('account-1', createdAt: DateTime.utc(2026, 8, 9), playerId: 'account'),
        answers: const [],
        levelUpdates: {ExerciseType.addition: accountLevel},
      );

      await repository.transferPlayerData(fromPlayerId: 'device', toPlayerId: 'account');

      expect((await repository.recentSessions('account')).map((s) => s.id), ['account-1']);
      expect((await repository.currentLevels('account'))[ExerciseType.addition]?.level, 80);
      expect((await repository.recentSessions('device')).map((s) => s.id), ['device-1']);
    });

    test('currentLevels est vide pour un joueur jamais joué', () async {
      final repository = InMemorySessionRepository();

      expect(await repository.currentLevels('unknown-player'), isEmpty);
    });

    test('currentLevels retrouve ce qui a été écrit via recordSession', () async {
      final repository = InMemorySessionRepository();
      final entry = LevelCacheEntry(level: 42, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 8, 8));

      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
        answers: const [],
        levelUpdates: {ExerciseType.addition: entry},
      );
      final levels = await repository.currentLevels('player-1');

      expect(levels[ExerciseType.addition]?.level, 42);
      expect(levels[ExerciseType.addition]?.sessionsPlayed, 1);
    });

    test('currentLevels ne mélange pas les joueurs', () async {
      final repository = InMemorySessionRepository();
      final entry = LevelCacheEntry(level: 77, sessionsPlayed: 1, updatedAt: DateTime.utc(2026, 8, 8));

      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8), playerId: 'player-a'),
        answers: const [],
        levelUpdates: {ExerciseType.addition: entry},
      );

      expect(await repository.currentLevels('player-b'), isEmpty);
    });

    test('averageElapsedMsByType moyenne par opération, réponses d\'un seul joueur', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
        answers: [
          answer('a1', 'session-1', operationType: 'addition', elapsedMs: 1000),
          answer('a2', 'session-1', operationType: 'addition', elapsedMs: 2000),
          answer('a3', 'session-1', operationType: 'subtraction', elapsedMs: 500),
        ],
        levelUpdates: const {},
      );
      // Réponse d'un autre joueur — ne doit pas entrer dans la moyenne.
      await repository.recordSession(
        session: session('session-2', createdAt: DateTime.utc(2026, 8, 8), playerId: 'player-b'),
        answers: [answer('a4', 'session-2', operationType: 'addition', elapsedMs: 9999)],
        levelUpdates: const {},
      );

      final result = await repository.averageElapsedMsByType('player-1');

      expect(result[ExerciseType.addition], 1500);
      expect(result[ExerciseType.subtraction], 500);
      expect(result.containsKey(ExerciseType.multiplication), isFalse);
    });

    test('sessionsSince ne retourne que les sessions du joueur à partir de la date, triées', () async {
      final repository = InMemorySessionRepository();
      await repository.recordSession(
        session: session('too-old', createdAt: DateTime.utc(2026, 7, 1)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('in-window-late', createdAt: DateTime.utc(2026, 8, 10)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('in-window-early', createdAt: DateTime.utc(2026, 8, 5)),
        answers: const [],
        levelUpdates: const {},
      );
      await repository.recordSession(
        session: session('other-player', createdAt: DateTime.utc(2026, 8, 5), playerId: 'player-b'),
        answers: const [],
        levelUpdates: const {},
      );

      final result = await repository.sessionsSince('player-1', DateTime.utc(2026, 8, 1));

      expect(result.map((s) => s.id), equals(['in-window-early', 'in-window-late']));
    });
  });
}
