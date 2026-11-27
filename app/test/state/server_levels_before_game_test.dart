import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/server_levels.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_trainer/composition_root.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

class _Server implements ServerLevelsSource {
  Map<ExerciseType, LevelCacheEntry> levels = const {};
  int calls = 0;

  /// Unreachable while set.
  bool down = false;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> fetch() async {
    calls++;
    if (down) throw Exception('offline');
    return levels;
  }
}

class _NeverCalledClient implements SessionUploadClient {
  @override
  Future<UploadOutcome> upload(SessionUpload upload) =>
      throw StateError('no upload in this test');
}

/// Phase 3a commit 2: the second device's game starts from the server's
/// levels, so the server accepts it instead of refusing it.
void main() {
  late InMemorySessionRepository repository;
  late _Server server;

  setUp(() async {
    repository = InMemorySessionRepository();
    server = _Server();
    // This device last saw addition at 12.00; the other device took it to
    // 18.50 on the server.
    await repository.replaceLevelCache('me', {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.fromHundredths(1200),
        sessionsPlayed: 3,
        updatedAt: DateTime.utc(2026, 11, 20),
      ),
    });
    server.levels = {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.fromHundredths(1850),
        sessionsPlayed: 9,
        updatedAt: DateTime.utc(2026, 11, 21),
      ),
    };
  });

  AppEnvironment environment({bool withServer = true}) => AppEnvironment(
    repository: repository,
    playerId: 'device',
    accountRepository: FakeAccountRepository(),
    profileRepository: FakeProfileRepository(),
    uploadClient: withServer ? _NeverCalledClient() : null,
    serverLevelsSource: withServer ? server : null,
  ).forPlayer('me');

  test('the game is built on the server levels', () async {
    final controller = await buildSessionController(environment(), {
      ExerciseType.addition,
    });
    addTearDown(controller.dispose);
    expect(
      controller.config.levels[ExerciseType.addition],
      Level.fromHundredths(1850),
    );
    expect(server.calls, 1);
  });

  // Phase 5.1 commit 1: read at sign-in, used at Start — one round trip,
  // made before the player pressed anything.
  test('the levels read ahead are the ones the game starts from', () async {
    final env = environment();
    await env.serverLevelsAhead!.start();
    expect(server.calls, 1);
    final controller = await buildSessionController(env, {
      ExerciseType.addition,
    });
    addTearDown(controller.dispose);
    expect(
      controller.config.levels[ExerciseType.addition],
      Level.fromHundredths(1850),
    );
    expect(server.calls, 1);
  });

  group('right after sign-in (Phase 6b commit 5, review M14)', () {
    Future<Level?> localAddition() async =>
        (await repository.currentLevels('me'))[ExerciseType.addition]?.level;

    test('the server levels replace the local ones; Home is told', () async {
      final env = environment();
      var told = 0;
      env.levelsRefresh!.addListener(() => told++);
      expect(await adoptServerLevelsAtSignIn(env), LevelSyncOutcome.adopted);
      expect(await localAddition(), Level.fromHundredths(1850));
      expect(told, 1);
      // Nothing new: nobody told again.
      expect(await adoptServerLevelsAtSignIn(env), LevelSyncOutcome.unchanged);
      expect(told, 1);
    });

    test('a game waiting to be sent: the local levels stay', () async {
      await repository.recordSession(
        session: PersistedSession(
          id: 'waiting',
          playerId: 'me',
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 4,
          totalScore: 40,
          levels: {ExerciseType.addition: Level.fromHundredths(1200)},
          createdAt: DateTime.utc(2026, 11, 22),
          rulesVersion: RulesVersion.current,
        ),
        answers: const [],
        levelUpdates: const {},
      );
      expect(
        await adoptServerLevelsAtSignIn(environment()),
        LevelSyncOutcome.pendingUploads,
      );
      expect(await localAddition(), Level.fromHundredths(1200));
      expect(server.calls, 0);
    });

    test('a server that cannot be reached: the local levels stay', () async {
      server.down = true;
      expect(
        await adoptServerLevelsAtSignIn(environment()),
        LevelSyncOutcome.unavailable,
      );
      expect(await localAddition(), Level.fromHundredths(1200));
    });

    test('no server: nothing asked', () async {
      expect(
        await adoptServerLevelsAtSignIn(environment(withServer: false)),
        LevelSyncOutcome.unavailable,
      );
      expect(server.calls, 0);
    });
  });

  test('a build without a server never asks, never resets', () async {
    final controller = await buildSessionController(
      environment(withServer: false),
      {ExerciseType.addition},
    );
    addTearDown(controller.dispose);
    expect(
      controller.config.levels[ExerciseType.addition],
      Level.fromHundredths(1200),
    );
    expect(server.calls, 0);
  });
}
