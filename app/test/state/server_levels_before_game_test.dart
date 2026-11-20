import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/sync/server_levels.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_trainer/composition_root.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

class _Server implements ServerLevelsSource {
  Map<ExerciseType, LevelCacheEntry> levels = const {};
  int calls = 0;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> fetch() async {
    calls++;
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
