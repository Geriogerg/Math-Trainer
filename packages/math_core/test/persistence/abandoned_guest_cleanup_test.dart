import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/abandoned_guest_cleanup.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:test/test.dart';

class _MemoryStore implements AbandonedGuestStore {
  final left = <String, DateTime>{};

  @override
  Future<Map<String, DateTime>> load() async => Map.of(left);

  @override
  Future<void> record(String guestId, DateTime at) async =>
      left.putIfAbsent(guestId, () => at);

  @override
  Future<void> forget(String guestId) async => left.remove(guestId);
}

void main() {
  final now = DateTime.utc(2026, 12, 31);

  Future<void> play(InMemorySessionRepository repository, String player) =>
      repository.recordSession(
        session: PersistedSession(
          id: 'session-$player',
          playerId: player,
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 1,
          totalScore: 0,
          levels: {ExerciseType.addition: Level.floor},
          createdAt: DateTime.utc(2026, 11, 1),
        ),
        answers: const [],
        levelUpdates: const {},
      );

  test('a guest left over 30 days ago loses its local games; newer and '
      'current players keep theirs', () async {
    final repository = InMemorySessionRepository();
    for (final p in ['old-guest', 'recent-guest', 'me']) {
      await play(repository, p);
    }
    final store = _MemoryStore()
      ..left['old-guest'] = now.subtract(const Duration(days: 31))
      ..left['recent-guest'] = now.subtract(const Duration(days: 29));

    final deleted = await deleteAbandonedGuests(
      store: store,
      repository: repository,
      now: now,
    );

    expect(deleted, ['old-guest']);
    expect(await repository.recentSessions('old-guest'), isEmpty);
    expect(await repository.recentSessions('recent-guest'), hasLength(1));
    expect(await repository.recentSessions('me'), hasLength(1));
    expect(store.left.keys, ['recent-guest']);
  });

  test('the first time a guest was left is kept', () async {
    final store = _MemoryStore();
    await store.record('g', DateTime.utc(2026, 1, 1));
    await store.record('g', DateTime.utc(2026, 6, 1));
    expect((await store.load())['g'], DateTime.utc(2026, 1, 1));
  });
}
