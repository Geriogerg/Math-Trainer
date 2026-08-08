import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/infrastructure/persistence/database.dart';
import 'package:math_trainer/infrastructure/persistence/sqflite_session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // sqflite n'a pas de plateforme (pas de device/émulateur) sous `flutter
  // test` sur la Dart VM : sqflite_common_ffi fournit une implémentation
  // basée sur sqlite3 natif qui tourne directement sur la VM.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SqfliteSessionRepository repository;

  setUp(() async {
    db = await openMathTrainerDatabase(inMemoryDatabasePath);
    repository = SqfliteSessionRepository(db);
  });

  tearDown(() => db.close());

  PersistedSession session(String id, {required DateTime createdAt}) {
    return PersistedSession(
      id: id,
      playerId: 'player-1',
      seed: 42,
      enabledTypes: const {ExerciseType.addition, ExerciseType.division},
      exerciseCount: 10,
      totalScore: 150,
      createdAt: createdAt,
    );
  }

  PersistedAnswer answer(String id, String sessionId) {
    return PersistedAnswer(
      id: id,
      sessionId: sessionId,
      exerciseType: 'arithmetic',
      operationType: 'addition',
      operands: const {'operandA': 4, 'operandB': 3},
      submittedValue: 7,
      isCorrect: true,
      elapsedMs: 1200,
      createdAt: DateTime.utc(2026, 8, 8),
      syncedAt: DateTime.utc(2026, 8, 8, 1),
    );
  }

  group('SqfliteSessionRepository', () {
    test('recordSession persiste session et réponses, relisibles ensuite', () async {
      final s = session('session-1', createdAt: DateTime.utc(2026, 8, 8));
      final answers = [answer('answer-1', 'session-1'), answer('answer-2', 'session-1')];

      await repository.recordSession(session: s, answers: answers);

      final sessions = await repository.recentSessions();
      final storedAnswers = await repository.answersForSession('session-1');

      expect(sessions, equals([s]));
      expect(storedAnswers, equals(answers));
    });

    test('answersForSession ne retourne que les réponses de la session demandée', () async {
      await repository.recordSession(
        session: session('session-1', createdAt: DateTime.utc(2026, 8, 8)),
        answers: [answer('answer-1', 'session-1')],
      );
      await repository.recordSession(
        session: session('session-2', createdAt: DateTime.utc(2026, 8, 9)),
        answers: [answer('answer-2', 'session-2')],
      );

      final result = await repository.answersForSession('session-1');

      expect(result.map((a) => a.id), equals(['answer-1']));
    });

    test('recentSessions trie du plus récent au plus ancien et respecte la limite', () async {
      await repository.recordSession(
        session: session('oldest', createdAt: DateTime.utc(2026, 8, 1)),
        answers: const [],
      );
      await repository.recordSession(
        session: session('newest', createdAt: DateTime.utc(2026, 8, 10)),
        answers: const [],
      );
      await repository.recordSession(
        session: session('middle', createdAt: DateTime.utc(2026, 8, 5)),
        answers: const [],
      );

      final result = await repository.recentSessions(limit: 2);

      expect(result.map((s) => s.id), equals(['newest', 'middle']));
    });

    test('recordSession écrit session et réponses dans une seule transaction', () async {
      final s = session('session-1', createdAt: DateTime.utc(2026, 8, 8));

      await repository.recordSession(
        session: s,
        answers: [answer('answer-1', 'session-1'), answer('answer-2', 'session-1')],
      );

      final storedAnswers = await repository.answersForSession('session-1');
      expect(storedAnswers, hasLength(2));
    });
  });
}
