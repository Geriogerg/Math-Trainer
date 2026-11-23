import 'dart:async';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_core/sync/session_upload_queue.dart';
import 'package:test/test.dart';

/// Answers from a script; records what it was sent.
class _ScriptedClient implements SessionUploadClient {
  final sent = <String>[];
  final outcomes = <String, UploadOutcome Function()>{};
  Completer<void>? gate;

  @override
  Future<UploadOutcome> upload(SessionUpload upload) async {
    await gate?.future;
    sent.add(upload.session.id);
    final outcome = outcomes[upload.session.id];
    if (outcome == null) {
      return UploadAccepted(syncedAt: DateTime.utc(2026, 11, 20));
    }
    return outcome();
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);
  final Duration duration;
  final void Function() callback;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

void main() {
  late InMemorySessionRepository repository;
  late _ScriptedClient client;
  late List<_FakeTimer> timers;
  late SessionUploadQueue queue;

  Future<void> store(
    String id,
    DateTime at, {
    bool withSequence = true,
    String player = 'me',
    RulesVersion rules = RulesVersion.v2,
  }) => repository.recordSession(
    session: PersistedSession(
      id: id,
      playerId: player,
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 1,
      totalScore: 0,
      levels: {ExerciseType.addition: Level.zero},
      createdAt: at,
      typeSequence: withSequence ? const [ExerciseType.addition] : null,
      rulesVersion: rules,
    ),
    answers: [
      PersistedAnswer(
        id: '$id-a',
        sessionId: id,
        exerciseType: 'arithmetic',
        operationType: 'addition',
        operands: const {'operandA': 1, 'operandB': 1},
        submittedValue: 2,
        isCorrect: true,
        elapsedMs: 900,
        createdAt: at,
      ),
    ],
    levelUpdates: const {},
  );

  setUp(() {
    repository = InMemorySessionRepository();
    client = _ScriptedClient();
    timers = [];
    queue = SessionUploadQueue(
      repository: repository,
      client: client,
      playerId: 'me',
      createTimer: (d, cb) {
        final t = _FakeTimer(d, cb);
        timers.add(t);
        return t;
      },
      retryDelays: const [Duration(seconds: 30), Duration(minutes: 1)],
    );
  });

  test(
    'sends oldest first, only this player\'s, and marks them synced',
    () async {
      await store('late', DateTime.utc(2026, 11, 3));
      await store('early', DateTime.utc(2026, 11, 1));
      await store('theirs', DateTime.utc(2026, 11, 2), player: 'other');

      final run = await queue.flush();

      expect(client.sent, ['early', 'late']);
      expect(run, (accepted: 2, refused: 0, stoppedOffline: false));
      expect(await repository.pendingUploads('me'), isEmpty);
      final answers = await repository.answersForSession('early');
      expect(answers.single.syncedAt, DateTime.utc(2026, 11, 20));
      expect(await queue.flush(), (
        accepted: 0,
        refused: 0,
        stoppedOffline: false,
      ));
    },
  );

  test('a refusal is final; server levels replace the cache', () async {
    await store('s1', DateTime.utc(2026, 11, 1));
    await store('s2', DateTime.utc(2026, 11, 2));
    final serverLevels = {
      ExerciseType.addition: LevelCacheEntry(
        level: Level.whole(12),
        sessionsPlayed: 4,
        updatedAt: DateTime.utc(2026, 10, 1),
      ),
    };
    client.outcomes['s1'] = () =>
        UploadRefused(reason: 'levelsMismatch', serverLevels: serverLevels);

    final run = await queue.flush();

    expect(run, (accepted: 1, refused: 1, stoppedOffline: false));
    expect(repository.uploadRefusal('s1'), 'levelsMismatch');
    expect(
      (await repository.currentLevels('me'))[ExerciseType.addition]!.level,
      Level.whole(12),
    );
    await queue.flush();
    expect(client.sent, ['s1', 's2']); // never sent again
  });

  test(
    'offline: stops, keeps the rest, retries later with a longer delay',
    () async {
      await store('s1', DateTime.utc(2026, 11, 1));
      await store('s2', DateTime.utc(2026, 11, 2));
      client.outcomes['s1'] = () => throw const UploadUnavailable('offline');

      expect(await queue.flush(), (
        accepted: 0,
        refused: 0,
        stoppedOffline: true,
      ));
      expect(client.sent, ['s1']);
      expect(timers.single.duration, const Duration(seconds: 30));
      expect(await repository.pendingUploads('me'), hasLength(2));

      // Still offline at the retry: the next delay.
      timers.single.callback();
      await Future<void>.delayed(Duration.zero);
      expect(timers.last.duration, const Duration(minutes: 1));
      timers.last.callback();
      await Future<void>.delayed(Duration.zero);
      expect(
        timers.last.duration,
        const Duration(minutes: 1),
      ); // the last repeats

      // Back online.
      client.outcomes.clear();
      timers.last.callback();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(await repository.pendingUploads('me'), isEmpty);
    },
  );

  test('a session of retired rules (v1) is refused locally, never sent — '
      'with or without its type sequence', () async {
    await store(
      'legacy',
      DateTime.utc(2026, 11, 1),
      withSequence: false,
      rules: RulesVersion.v1,
    );
    await store('v1', DateTime.utc(2026, 11, 2), rules: RulesVersion.v1);
    await store('v2', DateTime.utc(2026, 11, 3));
    final run = await queue.flush();
    expect(run.refused, 2);
    expect(client.sent, ['v2']);
    expect(repository.uploadRefusal('legacy'), 'rulesRetired');
    expect(repository.uploadRefusal('v1'), 'rulesRetired');
  });

  test('a flush during a run shares it, then runs once more', () async {
    await store('s1', DateTime.utc(2026, 11, 1));
    client.gate = Completer<void>();
    final first = queue.flush();
    await Future<void>.delayed(Duration.zero);
    await store('s2', DateTime.utc(2026, 11, 2)); // stored meanwhile
    final second = queue.flush();
    client.gate!.complete();
    expect(identical(await first, await second), isTrue);
    expect(client.sent, ['s1', 's2']);
  });

  test('dispose stops retrying', () async {
    await store('s1', DateTime.utc(2026, 11, 1));
    client.outcomes['s1'] = () => throw const UploadUnavailable('down');
    await queue.flush();
    queue.dispose();
    expect(timers.single.cancelled, isTrue);
  });
}
