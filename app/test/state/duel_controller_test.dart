import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/generation/list_exercise_source.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/session_config.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/state/duel_controller.dart';
import 'package:math_trainer/core/state/session_controller.dart';

import '../fake_duel_client.dart';

class _Timer implements Timer {
  _Timer(this.callback);
  final void Function() callback;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
  @override
  bool get isActive => !cancelled;
  @override
  int get tick => 0;
}

/// The pinned Basics duel (math_core's `duel_config_test.dart`).
final basics = DuelConfig(
  mode: DuelMode.basics,
  seed: 1,
  difficulty: 4,
  rulesVersion: RulesVersion.v8,
);
final count = DuelConfig(
  mode: DuelMode.count,
  seed: 987654321,
  difficulty: 2,
  rulesVersion: RulesVersion.v8,
);

/// Six right, each in 5 s.
final lane = QuizLane([
  for (var i = 0; i < 8; i++) (elapsedMs: 5000, correct: i < 6),
]);

void main() {
  late DateTime now;
  late List<_Timer> timers;
  late FakeDuelClient client;
  late MemoryDuelRunStore store;

  Timer fakeTimer(Duration _, void Function() callback) {
    final timer = _Timer(callback);
    timers.add(timer);
    return timer;
  }

  DuelController duel(DuelOffer offer) {
    client.know(offer);
    return DuelController(
      offer: offer,
      queue: DuelRunQueue(store: store, client: client, playerId: 'me'),
      clock: () => now,
      ticker: (_, _) => _Timer(() {}),
      countTimer: fakeTimer,
      quizController: (config) {
        final questions = config.questions();
        final types = {for (final q in questions) q.type};
        return SessionController(
          config: SessionConfig(
            seed: config.seed,
            enabledTypes: types,
            exerciseCount: questions.length,
            levels: {for (final t in types) t: Level.whole(40)},
            kind: SessionKind.training,
          ),
          exerciseSource: ListExerciseSource(questions),
          levelCacheOrchestrator: const NoLevelUpdates(),
          repository: InMemorySessionRepository(),
          playerId: 'me',
          clock: () => now,
          createTimer: fakeTimer,
          correctionDelay: null,
          questionTimeout: SessionController.defaultQuestionTimeout,
        );
      },
    );
  }

  /// Answers the current question after [seconds], right or not.
  void answer(DuelController d, {required bool right, int seconds = 4}) {
    now = now.add(Duration(seconds: seconds));
    final q = d.quiz!.state.currentExercise!;
    d.quiz!.submitAnswer(right ? q.correctAnswer : q.correctAnswer + 1);
  }

  setUp(() {
    now = DateTime.utc(2026, 11, 25);
    timers = [];
    client = FakeDuelClient();
    store = MemoryDuelRunStore();
  });

  final practice = DuelOffer(
    duelId: 'd1',
    kind: DuelKind.practice,
    config: basics,
    lane: lane,
  );

  test('a question duel: played, saved as it goes, sent, decided', () async {
    final d = duel(practice)..start();
    for (var i = 0; i < 7; i++) {
      answer(d, right: true);
    }
    await pumpEventQueue();
    // Saved after every answer, before the end.
    final saved = (await store.load('me')).single;
    expect((saved.run as QuizRun).answers.length, 7);
    expect(saved.complete, isFalse);
    // And told the server, step by step (plan v3.8: abandoned duels).
    expect(client.progressed.length, 7);
    expect((client.progressed.last.$2 as QuizRun).answers.length, 7);
    answer(d, right: false);
    await pumpEventQueue();
    expect(d.phase, DuelPhase.done);
    expect(d.verdict!.result, 1, reason: '7 right against 6');
    expect(d.result, 1);
    expect((client.submitted.single.$2 as QuizRun).answers.length, 8);
    expect(await store.load('me'), isEmpty, reason: 'left the queue');
  });

  test('the lanes: mine by answers, theirs at its own pace', () {
    final d = duel(practice)..start();
    expect(d.mine, (fraction: 0.0, value: 0));
    expect(d.theirs, (fraction: 0.0, value: 0));
    answer(d, right: true, seconds: 4);
    expect(d.mine, (fraction: 1 / 8, value: 1));
    // 4 s in: the opponent (5 s a question) has not answered yet.
    expect(d.theirs!.value, 0);
    now = now.add(const Duration(seconds: 7)); // 11 s: two answers
    expect(d.theirs, (fraction: 2 / 8, value: 2));
    // After their 7th answer (35 s) — a miss — their lane pauses 1 s.
    now = DateTime.utc(2026, 11, 25).add(const Duration(seconds: 40));
    expect(d.theirs, (fraction: 7 / 8, value: 6));
  });

  test('quitting sends the run with the rest as timeouts', () async {
    final d = duel(practice)..start();
    answer(d, right: true);
    answer(d, right: true);
    d.quit();
    await pumpEventQueue();
    final sent = client.submitted.single.$2 as QuizRun;
    expect(sent.answers.length, 8);
    expect(sent.answers.skip(2).every((a) => a == DuelAnswer.none), isTrue);
    expect(d.result, 0);
  });

  test('offline: the result shown, the run kept, sent again', () async {
    client.failure = const DuelUnavailable('offline');
    final d = duel(practice)..start();
    for (var i = 0; i < 8; i++) {
      answer(d, right: true);
    }
    await pumpEventQueue();
    expect(d.pending, isTrue);
    expect(d.result, 1, reason: 'reckoned on the device');
    expect((await store.load('me')).single.complete, isTrue);
    client.failure = null;
    await d.retry();
    expect(d.verdict, isNotNull);
    expect(d.pending, isFalse);
  });

  test('refused by the server: said so', () async {
    client.failure = const DuelRefused('notOpen');
    final d = duel(practice)..start();
    for (var i = 0; i < 8; i++) {
      answer(d, right: true);
    }
    await pumpEventQueue();
    expect(d.refusal, 'notOpen');
    expect(d.pending, isFalse);
    expect(await store.load('me'), isEmpty, reason: 'never resent');
  });

  test('Get the count: three rounds of 30 s, improvements kept', () async {
    final offer = DuelOffer(
      duelId: 'c1',
      kind: DuelKind.practice,
      config: count,
      lane: CountLane([
        for (var i = 0; i < 3; i++)
          CountLaneRound(
            baseDistance: 100,
            improvements: const [(atMs: 20000, distance: 2)],
          ),
      ]),
    );
    final d = duel(offer)..start();
    expect(d.roundIndex, 0);
    expect(d.round!.roundSeconds, 30);
    // Solve round 1 with its shortest solution, 6 s in.
    now = now.add(const Duration(seconds: 6));
    final round = d.round!;
    for (final step in round.solution) {
      int idOf(int value) =>
          round.board.tiles.firstWhere((t) => !t.used && t.value == value).id;
      final left = idOf(step.left);
      round.tapTile(left);
      round.tapOperator(step.operator);
      round.tapTile(
        round.board.tiles
            .firstWhere((t) => !t.used && t.value == step.right && t.id != left)
            .id,
      );
    }
    expect(d.roundIndex, 1, reason: 'solved: the next round');
    expect(d.mine.value, d.round!.bestDistance);
    // Rounds 2 and 3 run out of time.
    for (var r = 0; r < 2; r++) {
      for (var s = 0; s < 30; s++) {
        timers.last.callback();
      }
    }
    await pumpEventQueue();
    expect(d.phase, DuelPhase.done);
    final sent = client.submitted.single.$2 as CountRun;
    expect(sent.rounds.length, 3);
    expect(sent.rounds.first.improvements.last.value, 442);
    expect(d.verdict!.you.points, greaterThan(0));
  });
}
