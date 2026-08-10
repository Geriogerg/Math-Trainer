import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:test/test.dart';

void main() {
  group('PersistedAnswer', () {
    PersistedAnswer buildAnswer({DateTime? syncedAt}) {
      return PersistedAnswer(
        id: 'answer-1',
        sessionId: 'session-1',
        exerciseType: 'arithmetic',
        operationType: 'addition',
        operands: const {'operandA': 4, 'operandB': 3},
        submittedValue: 7,
        isCorrect: true,
        elapsedMs: 1200,
        createdAt: DateTime.utc(2026, 8, 8),
        syncedAt: syncedAt,
      );
    }

    test('deux instances avec les mêmes valeurs sont égales', () {
      expect(buildAnswer(), equals(buildAnswer()));
      expect(buildAnswer().hashCode, equals(buildAnswer().hashCode));
    });

    test('copyWith sans argument ne modifie rien', () {
      final original = buildAnswer();
      expect(original.copyWith(), equals(original));
    });

    test('copyWith peut poser syncedAt', () {
      final syncedAt = DateTime.utc(2026, 8, 9);
      final updated = buildAnswer().copyWith(syncedAt: syncedAt);

      expect(updated.syncedAt, syncedAt);
    });

    test('copyWith peut remettre syncedAt à null explicitement', () {
      final withSync = buildAnswer(syncedAt: DateTime.utc(2026, 8, 9));
      final reverted = withSync.copyWith(syncedAt: null);

      expect(reverted.syncedAt, isNull);
    });

    test('refuse un createdAt qui n\'est pas en UTC', () {
      expect(
        () => PersistedAnswer(
          id: 'answer-1',
          sessionId: 'session-1',
          exerciseType: 'arithmetic',
          operationType: 'addition',
          operands: const {'operandA': 4, 'operandB': 3},
          submittedValue: 7,
          isCorrect: true,
          elapsedMs: 1200,
          createdAt: DateTime(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });

    test('refuse un syncedAt qui n\'est pas en UTC', () {
      expect(
        () => buildAnswer().copyWith(syncedAt: DateTime(2026, 8, 9)),
        throwsArgumentError,
      );
    });
  });

  group('PersistedSession', () {
    PersistedSession buildSession({DateTime? syncedAt}) {
      return PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: const {ExerciseType.addition, ExerciseType.division},
        exerciseCount: 10,
        totalScore: 150,
        levels: const {ExerciseType.addition: 42, ExerciseType.division: 17},
        createdAt: DateTime.utc(2026, 8, 8),
        syncedAt: syncedAt,
      );
    }

    test('deux instances avec les mêmes valeurs sont égales', () {
      expect(buildSession(), equals(buildSession()));
      expect(buildSession().hashCode, equals(buildSession().hashCode));
    });

    test('enabledTypes construits dans un ordre d\'insertion différent restent égaux', () {
      final a = PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: {ExerciseType.power, ExerciseType.division, ExerciseType.addition},
        exerciseCount: 10,
        totalScore: 150,
        levels: const {},
        createdAt: DateTime.utc(2026, 8, 8),
      );
      final b = PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: {ExerciseType.addition, ExerciseType.division, ExerciseType.power},
        exerciseCount: 10,
        totalScore: 150,
        levels: const {},
        createdAt: DateTime.utc(2026, 8, 8),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('levels construits dans un ordre d\'insertion différent restent égaux', () {
      final a = buildSession();
      final b = PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: const {ExerciseType.addition, ExerciseType.division},
        exerciseCount: 10,
        totalScore: 150,
        levels: const {ExerciseType.division: 17, ExerciseType.addition: 42},
        createdAt: DateTime.utc(2026, 8, 8),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('un niveau différent rend deux sessions inégales', () {
      final a = buildSession();
      final b = PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: const {ExerciseType.addition, ExerciseType.division},
        exerciseCount: 10,
        totalScore: 150,
        levels: const {ExerciseType.addition: 99, ExerciseType.division: 17},
        createdAt: DateTime.utc(2026, 8, 8),
      );

      expect(a, isNot(equals(b)));
    });

    test('copyWith peut poser puis remettre syncedAt à null', () {
      final synced = buildSession().copyWith(syncedAt: DateTime.utc(2026, 8, 9));
      expect(synced.syncedAt, isNotNull);

      final reverted = synced.copyWith(syncedAt: null);
      expect(reverted.syncedAt, isNull);
    });

    test('refuse un createdAt qui n\'est pas en UTC', () {
      expect(
        () => PersistedSession(
          id: 'session-1',
          playerId: 'player-1',
          seed: 42,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 10,
          totalScore: 150,
          levels: const {},
          createdAt: DateTime(2026, 8, 8),
        ),
        throwsArgumentError,
      );
    });
  });
}
