import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/duel_run_queue.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_trainer/core/state/online_controller.dart';
import 'package:math_trainer/presentation/strings/duel_texts.dart';

import '../fake_duel_client.dart';
import '../presentation/duel_flow_test.dart' show basicsOffer;
import '../presentation/online_screen_test.dart' show FakeOnlineRepository;

/// Phase 6b commit 5 (review M15): a duel left unfinished on this device
/// was sent silently at the next start — now the player is told, once.
void main() {
  test(
    'a duel left unfinished and sent at the next load is told once',
    () async {
      final client = FakeDuelClient()
        ..failure = const DuelUnavailable('offline');
      final offer = basicsOffer();
      client.know(offer);
      final queue = DuelRunQueue(
        store: MemoryDuelRunStore(),
        client: client,
        playerId: 'me',
      );
      await queue.saveProgress(
        offer,
        QuizRun([
          for (var i = 0; i < 3; i++) DuelAnswer(value: 1, elapsedMs: 4000),
        ]),
      );
      client.failure = null;
      final controller = OnlineController(
        repository: FakeOnlineRepository(OnlineOverview.guest),
        levels: () async => {},
        client: client,
        queue: queue,
      );
      addTearDown(controller.dispose);
      var told = 0;
      controller.addListener(() => told++);
      await controller.load();
      await pumpEventQueue();
      expect(controller.takeUnfinishedSent(), [DuelMode.basics]);
      expect(controller.takeUnfinishedSent(), isEmpty, reason: 'once');
      expect(told, greaterThan(0));
      // Nothing waits any more: the next load says nothing.
      await controller.load();
      await pumpEventQueue();
      expect(controller.takeUnfinishedSent(), isEmpty);
    },
  );

  test('what the player reads', () {
    expect(
      unfinishedDuelsSentText([DuelMode.basics]),
      'Your unfinished Basics duel was sent: what you had not played counts '
      'as missed.',
    );
    expect(
      unfinishedDuelsSentText([DuelMode.count, DuelMode.advanced]),
      '2 unfinished duels were sent: what you had not played counts as '
      'missed.',
    );
  });
}
