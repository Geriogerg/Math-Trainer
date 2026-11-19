import 'dart:async';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/server_levels.dart';
import 'package:test/test.dart';

class _FakeSource implements ServerLevelsSource {
  _FakeSource(this.answer);
  Future<Map<ExerciseType, LevelCacheEntry>> Function() answer;
  int calls = 0;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> fetch() {
    calls++;
    return answer();
  }
}

LevelCacheEntry _entry(int hundredths, int played) => LevelCacheEntry(
  level: Level.fromHundredths(hundredths),
  sessionsPlayed: played,
  updatedAt: DateTime.utc(2026, 11, 21, 10),
);

void main() {
  late InMemorySessionRepository repository;
  final local = {ExerciseType.addition: _entry(1200, 3)};
  final server = {
    ExerciseType.addition: _entry(1850, 7),
    ExerciseType.division: _entry(900, 2),
  };

  setUp(() async {
    repository = InMemorySessionRepository();
    await repository.replaceLevelCache('me', local);
  });

  Future<LevelSyncOutcome> sync(_FakeSource source, {Duration? timeout}) =>
      syncLevelsBeforeGame(
        repository: repository,
        source: source,
        playerId: 'me',
        timeout: timeout ?? const Duration(seconds: 2),
      );

  test('different server levels replace the local cache', () async {
    final outcome = await sync(_FakeSource(() async => server));
    expect(outcome, LevelSyncOutcome.adopted);
    final now = await repository.currentLevels('me');
    expect(now[ExerciseType.addition]!.level, Level.fromHundredths(1850));
    expect(now[ExerciseType.addition]!.sessionsPlayed, 7);
    expect(now[ExerciseType.division]!.level, Level.fromHundredths(900));
  });

  test('a type the server never saw goes back to the floor', () async {
    // The server expects level 1 for it: a game from the local level would
    // be refused.
    final outcome = await sync(_FakeSource(() async => const {}));
    expect(outcome, LevelSyncOutcome.adopted);
    expect(await repository.currentLevels('me'), isEmpty);
  });

  test('same level and count: nothing written', () async {
    final sameButNewer = {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.fromHundredths(1200),
        sessionsPlayed: 3,
        updatedAt: DateTime.utc(2030),
      ),
    };
    final outcome = await sync(_FakeSource(() async => sameButNewer));
    expect(outcome, LevelSyncOutcome.unchanged);
    expect(
      (await repository.currentLevels('me'))[ExerciseType.addition]!.updatedAt,
      DateTime.utc(2026, 11, 21, 10),
    );
  });

  test('a different session count alone is a difference', () async {
    final outcome = await sync(
      _FakeSource(() async => {ExerciseType.addition: _entry(1200, 4)}),
    );
    expect(outcome, LevelSyncOutcome.adopted);
  });

  test('pending uploads: the server is not even asked', () async {
    await repository.recordSession(
      session: PersistedSession(
        id: 's1',
        playerId: 'me',
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 1,
        totalScore: 0,
        levels: {ExerciseType.addition: Level.fromHundredths(1200)},
        createdAt: DateTime.utc(2026, 11, 21, 9),
        typeSequence: const [ExerciseType.addition],
      ),
      answers: const [],
      levelUpdates: const {},
    );
    final source = _FakeSource(() async => server);
    expect(await sync(source), LevelSyncOutcome.pendingUploads);
    expect(source.calls, 0);
    expect(
      (await repository.currentLevels('me'))[ExerciseType.addition]!.level,
      Level.fromHundredths(1200),
    );
  });

  test('settled sessions (accepted or refused) do not block it', () async {
    for (final id in ['ok', 'no']) {
      await repository.recordSession(
        session: PersistedSession(
          id: id,
          playerId: 'me',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 1,
          totalScore: 0,
          levels: const {},
          createdAt: DateTime.utc(2026, 11, 21, 9),
          typeSequence: const [ExerciseType.addition],
        ),
        answers: const [],
        levelUpdates: const {},
      );
    }
    await repository.markSynced('ok', DateTime.utc(2026, 11, 21, 9, 1));
    await repository.markUploadRefused('no', 'levelsMismatch');
    expect(
      await sync(_FakeSource(() async => server)),
      LevelSyncOutcome.adopted,
    );
  });

  test('a failure keeps the local levels', () async {
    final outcome = await sync(
      _FakeSource(() async => throw const FormatException('bad')),
    );
    expect(outcome, LevelSyncOutcome.unavailable);
    expect(
      (await repository.currentLevels('me'))[ExerciseType.addition]!.level,
      Level.fromHundredths(1200),
    );
  });

  test('no answer in time: the game does not wait', () async {
    final never = Completer<Map<ExerciseType, LevelCacheEntry>>();
    final outcome = await sync(
      _FakeSource(() => never.future),
      timeout: const Duration(milliseconds: 20),
    );
    expect(outcome, LevelSyncOutcome.unavailable);
  });
}
