import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_trainer/core/state/account_deletion_controller.dart';

class _Accounts implements AccountRepository {
  @override
  Future<String?> accessToken() async => 'test-token';
  AccountException? deleteError;
  final calls = <String>[];

  @override
  Stream<Account?> get authState => const Stream.empty();

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    if (deleteError case final e?) throw e;
  }

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
    required DateTime ageDeclaredAt,
  }) => throw UnimplementedError();

  @override
  Future<Account> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<Account> signInAnonymously() => throw UnimplementedError();
}

class _WipeFails extends InMemorySessionRepository {
  @override
  Future<void> deletePlayerData(String playerId) async =>
      throw Exception('storage blocked');
}

Future<void> _play(InMemorySessionRepository repository, String playerId) =>
    repository.recordSession(
      session: PersistedSession(
        id: 'session-$playerId',
        playerId: playerId,
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        totalScore: 40,
        levels: {ExerciseType.addition: Level.zero},
        createdAt: DateTime.utc(2026, 11, 19),
      ),
      answers: const [],
      levelUpdates: {
        ExerciseType.addition: LevelCacheEntry(
          level: Level.whole(12),
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 11, 19),
        ),
      },
    );

void main() {
  test(
    'server, then this device, then sign-out — other players untouched',
    () async {
      final accounts = _Accounts();
      final repository = InMemorySessionRepository();
      await _play(repository, 'me');
      await _play(repository, 'someone-else');

      final outcome = await AccountDeletionController(
        accounts: accounts,
        repository: repository,
        playerId: 'me',
      ).delete();

      expect(outcome, AccountDeletionOutcome.deleted);
      expect(accounts.calls, ['deleteAccount', 'signOut']);
      expect(await repository.recentSessions('me'), isEmpty);
      expect(await repository.currentLevels('me'), isEmpty);
      expect(await repository.recentSessions('someone-else'), hasLength(1));
    },
  );

  test('server refuses: nothing deleted locally, still signed in', () async {
    final accounts = _Accounts()
      ..deleteError = const AccountException(AccountFailure.network);
    final repository = InMemorySessionRepository();
    await _play(repository, 'me');
    final controller = AccountDeletionController(
      accounts: accounts,
      repository: repository,
      playerId: 'me',
    );

    final outcome = await controller.delete();

    expect(outcome, AccountDeletionOutcome.failed);
    expect(controller.failure, AccountFailure.network);
    expect(controller.isDeleting, isFalse);
    expect(accounts.calls, ['deleteAccount']);
    expect(await repository.recentSessions('me'), hasLength(1));
  });

  test('local wipe fails after the server deletion: still signs out, says '
      'what stayed', () async {
    final accounts = _Accounts();

    final outcome = await AccountDeletionController(
      accounts: accounts,
      repository: _WipeFails(),
      playerId: 'me',
    ).delete();

    expect(outcome, AccountDeletionOutcome.deletedButLocalDataKept);
    expect(accounts.calls, ['deleteAccount', 'signOut']);
  });
}
