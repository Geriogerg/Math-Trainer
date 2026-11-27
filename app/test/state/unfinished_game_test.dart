import 'dart:async';
import 'dart:convert';

import 'package:math_core/generation/exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/unfinished_game.dart';
import 'package:test/test.dart';

/// Phase 6b commit 2 (`doc/levels.md` v1.6, "Quitting never pays"): a
/// Levelling game is kept after every answer; a game left by closing the
/// tab is stored at the next start, and under rules v9 it counts.

/// Keeps the game as JSON, like the real store: what a start reads back.
class _MemoryStore implements UnfinishedGameStore {
  String? text;
  int saves = 0;

  @override
  Future<void> save(SessionUpload game) async {
    saves++;
    text = jsonEncode(game.toJson());
  }

  @override
  Future<SessionUpload?> load() async =>
      text == null ? null : SessionUpload.fromJson(jsonDecode(text!));

  @override
  Future<void> clear() async => text = null;
}

class _Source extends ExerciseSource {
  int _i = 0;

  @override
  Exercise next() => ArithmeticExercise(
    operandA: _i++,
    operandB: 1,
    operationType: OperationType.addition,
  );
}

class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}

const _player = 'player-1';

SessionController _game({
  required InMemorySessionRepository repository,
  required UnfinishedGameStore store,
  RulesVersion rules = RulesVersion.current,
  int questions = 10,
}) {
  var ids = 0;
  return SessionController(
    config: SessionConfig(
      seed: 1,
      enabledTypes: {ExerciseType.addition},
      exerciseCount: questions,
      levels: {ExerciseType.addition: Level.whole(50)},
      typeSequence: List.filled(questions, ExerciseType.addition),
      rulesVersion: rules,
    ),
    exerciseSource: _Source(),
    repository: repository,
    playerId: _player,
    clock: () => DateTime.utc(2026, 11, 27, 10),
    idGenerator: () => 'id-${ids++}',
    createTimer: (_, _) => _InertTimer(),
    unfinishedGames: store,
  );
}

void main() {
  test('kept after every answer, with the ids the game is stored under; '
      'cleared once it is stored', () async {
    final repository = InMemorySessionRepository();
    final store = _MemoryStore();
    final controller = _game(repository: repository, store: store, questions: 3)
      ..start();
    controller.submitAnswer(1); // 0 + 1, right
    await Future<void>.delayed(Duration.zero);
    var kept = await store.load();
    expect(kept!.answers, hasLength(1));
    expect(kept.session.id, 'id-0');
    expect(kept.answers.single.id, 'id-1');
    controller.submitAnswer(2); // 1 + 1, right
    await Future<void>.delayed(Duration.zero);
    kept = await store.load();
    expect(kept!.answers.map((a) => a.id), ['id-1', 'id-2']);
    controller.submitAnswer(3); // the last: the game is stored
    await controller.pendingPersistence;
    expect(store.text, isNull, reason: 'stored, so no longer kept');
    final sessions = await repository.recentSessions(_player);
    expect(sessions.single.id, 'id-0');
    expect((await repository.answersForSession('id-0')).map((a) => a.id), [
      'id-1',
      'id-2',
      'id-3',
    ]);
  });

  test('a tab closed after 3 answers of 10: the next start stores the game, '
      'its 7 questions left as timeouts (rules v9)', () async {
    final repository = InMemorySessionRepository();
    final store = _MemoryStore();
    final controller = _game(repository: repository, store: store)..start();
    for (var i = 1; i <= 3; i++) {
      controller.submitAnswer(i);
    }
    await Future<void>.delayed(Duration.zero);
    // The tab closes: nothing else happens to this controller.
    expect(await repository.recentSessions(_player), isEmpty);

    expect(
      await recoverUnfinishedGame(store: store, repository: repository),
      isTrue,
    );
    final session = (await repository.recentSessions(_player)).single;
    expect(session.exerciseCount, 10);
    expect(await repository.answersForSession(session.id), hasLength(3));
    // 3 right of 10: q = 0.3 → −3 × min(1, 0.32 / 0.35) = −2.74.
    expect(
      (await repository.currentLevels(_player))[ExerciseType.addition]!.level,
      Level.fromHundredths(5000 - 274),
    );
    expect(store.text, isNull);
    // A second start finds nothing.
    expect(
      await recoverUnfinishedGame(store: store, repository: repository),
      isFalse,
    );
  });

  test('a game already stored is never stored twice', () async {
    final repository = InMemorySessionRepository();
    final store = _MemoryStore();
    final controller = _game(repository: repository, store: store)..start();
    controller.submitAnswer(1);
    await Future<void>.delayed(Duration.zero);
    final kept = store.text;
    controller.abandon();
    await controller.pendingPersistence;
    // The write landed but the tab closed before the clear.
    store.text = kept;
    expect(
      await recoverUnfinishedGame(store: store, repository: repository),
      isFalse,
    );
    expect(await repository.recentSessions(_player), hasLength(1));
    expect(store.text, isNull);
  });

  test('rules v8: the kept game is stored, no level moves', () async {
    final repository = InMemorySessionRepository();
    final store = _MemoryStore();
    final controller = _game(
      repository: repository,
      store: store,
      rules: RulesVersion.v8,
    )..start();
    controller.submitAnswer(1);
    await Future<void>.delayed(Duration.zero);
    expect(
      await recoverUnfinishedGame(store: store, repository: repository),
      isTrue,
    );
    expect(await repository.recentSessions(_player), hasLength(1));
    expect(await repository.currentLevels(_player), isEmpty);
  });

  test('a kept game that cannot be read is dropped', () async {
    final store = _MemoryStore()..text = '{"session": 3}';
    expect(
      await recoverUnfinishedGame(
        store: store,
        repository: InMemorySessionRepository(),
      ),
      isFalse,
    );
    expect(store.text, isNull);
  });
}
