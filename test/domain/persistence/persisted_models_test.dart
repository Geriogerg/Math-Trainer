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

    test('two instances with the same values are equal', () {
      expect(buildAnswer(), equals(buildAnswer()));
      expect(buildAnswer().hashCode, equals(buildAnswer().hashCode));
    });

    test('copyWith without arguments changes nothing', () {
      final original = buildAnswer();
      expect(original.copyWith(), equals(original));
    });

    test('copyWith can set syncedAt', () {
      final syncedAt = DateTime.utc(2026, 8, 9);
      final updated = buildAnswer().copyWith(syncedAt: syncedAt);

      expect(updated.syncedAt, syncedAt);
    });

    test('copyWith can set syncedAt back to null explicitly', () {
      final withSync = buildAnswer(syncedAt: DateTime.utc(2026, 8, 9));
      final reverted = withSync.copyWith(syncedAt: null);

      expect(reverted.syncedAt, isNull);
    });

    test('rejects a createdAt that is not UTC', () {
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

    test('rejects a syncedAt that is not UTC', () {
      expect(
        () => buildAnswer().copyWith(syncedAt: DateTime(2026, 8, 9)),
        throwsArgumentError,
      );
    });
  });

  group('PersistedSession', () {
    PersistedSession buildSession({
      DateTime? syncedAt,
      double? overallLevelAfter,
    }) {
      return PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: const {ExerciseType.addition, ExerciseType.division},
        exerciseCount: 10,
        totalScore: 150,
        levels: const {ExerciseType.addition: 42, ExerciseType.division: 17},
        createdAt: DateTime.utc(2026, 8, 8),
        overallLevelAfter: overallLevelAfter,
        syncedAt: syncedAt,
      );
    }

    test('two instances with the same values are equal', () {
      expect(buildSession(), equals(buildSession()));
      expect(buildSession().hashCode, equals(buildSession().hashCode));
    });

    test('enabledTypes built in a different insertion order stay equal', () {
      final a = PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: {
          ExerciseType.power,
          ExerciseType.division,
          ExerciseType.addition,
        },
        exerciseCount: 10,
        totalScore: 150,
        levels: const {},
        createdAt: DateTime.utc(2026, 8, 8),
      );
      final b = PersistedSession(
        id: 'session-1',
        playerId: 'player-1',
        seed: 42,
        enabledTypes: {
          ExerciseType.addition,
          ExerciseType.division,
          ExerciseType.power,
        },
        exerciseCount: 10,
        totalScore: 150,
        levels: const {},
        createdAt: DateTime.utc(2026, 8, 8),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('levels built in a different insertion order stay equal', () {
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

    test('a different level makes two sessions unequal', () {
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

    test('copyWith can set then reset syncedAt to null', () {
      final synced = buildSession().copyWith(
        syncedAt: DateTime.utc(2026, 8, 9),
      );
      expect(synced.syncedAt, isNotNull);

      final reverted = synced.copyWith(syncedAt: null);
      expect(reverted.syncedAt, isNull);
    });

    test('rejects a createdAt that is not UTC', () {
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

    test('a different overall level after makes two sessions unequal', () {
      expect(
        buildSession(overallLevelAfter: 12.5),
        isNot(equals(buildSession(overallLevelAfter: 13))),
      );
      expect(
        buildSession(overallLevelAfter: 12.5),
        isNot(equals(buildSession(overallLevelAfter: null))),
      );
    });

    test('copyWith keeps the overall level after', () {
      expect(
        buildSession(
          overallLevelAfter: 12.5,
        ).copyWith(playerId: 'compte').overallLevelAfter,
        12.5,
      );
    });

    test('rejects an overall level outside [1, 100]', () {
      expect(() => buildSession(overallLevelAfter: 0.5), throwsArgumentError);
      expect(() => buildSession(overallLevelAfter: 100.5), throwsArgumentError);
      expect(buildSession(overallLevelAfter: 1).overallLevelAfter, 1);
      expect(buildSession(overallLevelAfter: 100).overallLevelAfter, 100);
    });
  });
}
