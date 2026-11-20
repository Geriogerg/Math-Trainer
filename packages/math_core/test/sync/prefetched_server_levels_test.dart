import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/server_levels.dart';
import 'package:test/test.dart';

/// Answers the n-th call with `answers[n]` (the last one repeats).
class _CountingSource implements ServerLevelsSource {
  _CountingSource(this.answers);
  final List<Map<ExerciseType, LevelCacheEntry>> answers;
  int calls = 0;
  Object? failWith;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> fetch() async {
    final i = calls++;
    if (failWith case final error?) throw error;
    return answers[i < answers.length ? i : answers.length - 1];
  }
}

LevelCacheEntry _entry(int hundredths) => LevelCacheEntry(
  level: Level.fromHundredths(hundredths),
  sessionsPlayed: 3,
  updatedAt: DateTime.utc(2026, 11, 21, 10),
);

void main() {
  late InMemorySessionRepository repository;
  final first = {ExerciseType.addition: _entry(1200)};
  final second = {ExerciseType.addition: _entry(1500)};

  setUp(() => repository = InMemorySessionRepository());

  Future<void> store(String id, {bool synced = false, int hour = 9}) async {
    await repository.recordSession(
      session: PersistedSession(
        id: id,
        playerId: 'me',
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 1,
        totalScore: 0,
        levels: {ExerciseType.addition: Level.fromHundredths(1200)},
        createdAt: DateTime.utc(2026, 11, 21, hour),
        typeSequence: const [ExerciseType.addition],
      ),
      answers: const [],
      levelUpdates: const {},
    );
    if (synced) await repository.markSynced(id, DateTime.utc(2026, 11, 21, 9));
  }

  PrefetchedServerLevels prefetch(_CountingSource source) =>
      PrefetchedServerLevels(
        source: source,
        repository: repository,
        playerId: 'me',
      );

  test('the early read answers the next fetch: one round trip', () async {
    final source = _CountingSource([first, second]);
    final levels = prefetch(source);
    await levels.start();
    expect(source.calls, 1);
    expect(await levels.fetch(), first);
    expect(source.calls, 1);
  });

  test('used once: the fetch after reads the server again', () async {
    final source = _CountingSource([first, second]);
    final levels = prefetch(source);
    await levels.start();
    await levels.fetch();
    expect(await levels.fetch(), second);
    expect(source.calls, 2);
  });

  test('without start, fetch reads the server', () async {
    final source = _CountingSource([first]);
    expect(await prefetch(source).fetch(), first);
    expect(source.calls, 1);
  });

  test('sessions waiting for upload: no early read', () async {
    await store('pending');
    final source = _CountingSource([first, second]);
    final levels = prefetch(source);
    await levels.start();
    expect(source.calls, 0);
    expect(await levels.fetch(), first);
  });

  test('a session stored since the early read: read again', () async {
    await store('old', synced: true);
    final source = _CountingSource([first, second]);
    final levels = prefetch(source);
    await levels.start();
    // A placement played meanwhile, then uploaded: the server moved on.
    await store('placement', synced: true, hour: 10);
    expect(await levels.fetch(), second);
    expect(source.calls, 2);
  });

  test(
    'the first session ever, stored since the early read: read again',
    () async {
      final source = _CountingSource([first, second]);
      final levels = prefetch(source);
      await levels.start();
      await store('first', synced: true);
      expect(await levels.fetch(), second);
    },
  );

  test('an early read that failed reaches fetch as its error', () async {
    final source = _CountingSource([first])..failWith = Exception('offline');
    final levels = prefetch(source);
    await levels.start();
    await expectLater(levels.fetch(), throwsException);
    // syncLevelsBeforeGame turns that into "unavailable".
    source.failWith = Exception('offline');
    final outcome = await syncLevelsBeforeGame(
      repository: repository,
      source: levels,
      playerId: 'me',
    );
    expect(outcome, LevelSyncOutcome.unavailable);
  });
}
