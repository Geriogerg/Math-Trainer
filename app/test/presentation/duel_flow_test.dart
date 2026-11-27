import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/method/method_for.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/method_labels.dart';
import 'package:math_trainer/presentation/duel/duel_flow_screen.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_duel_client.dart';
import '../fake_profile_repository.dart';
import 'golden_test_utils.dart';

/// The pinned Basics duel's answers (math_core's `duel_config_test.dart`).
const answers = [7897, 3330, 3949, 259, 147, 108, 7957, 17050];

/// Léa: five right at once, then three timeouts — on screen, she has 5
/// whenever the player looks (the mockup's lanes).
DuelOffer basicsOffer() => DuelOffer(
  duelId: 'd1',
  kind: DuelKind.pool,
  config: DuelConfig(
    mode: DuelMode.basics,
    seed: 1,
    difficulty: 4,
    rulesVersion: RulesVersion.v8,
  ),
  lane: QuizLane([
    for (var i = 0; i < 8; i++) (elapsedMs: i < 5 ? 0 : 30000, correct: i < 5),
  ]),
  opponent: const DuelOpponent(
    id: 'lea',
    name: 'Léa',
    rating: 1520,
    ratedDuels: 14,
  ),
);

DuelOffer countOffer() => DuelOffer(
  duelId: 'c1',
  kind: DuelKind.pool,
  config: DuelConfig(
    mode: DuelMode.count,
    seed: 987654321,
    difficulty: 2,
    rulesVersion: RulesVersion.v8,
  ),
  lane: CountLane([
    for (var i = 0; i < 3; i++)
      CountLaneRound(
        baseDistance: 342,
        improvements: const [(atMs: 0, distance: 42)],
      ),
  ]),
  opponent: const DuelOpponent(id: 'lea', name: 'Léa'),
);

void main() {
  setUpAll(loadInterFontForGoldens);

  late FakeDuelClient client;
  var now = DateTime.utc(2026, 11, 25);

  Future<void> pumpDuel(WidgetTester tester, ThemeData theme) async {
    await setGoldenSurfaceSize(tester);
    client = FakeDuelClient(offers: [basicsOffer(), countOffer()]);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'device',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      duelClient: client,
      duelRunStore: MemoryDuelRunStore(),
    ).forPlayer('me');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: DuelFlowScreen(
          environment: environment,
          load: () => client.find(DuelMode.basics),
          clock: () => now,
        ),
      ),
    );
  }

  /// Each answer 4 s after the last.
  Future<void> type(WidgetTester tester, int value) async {
    now = now.add(const Duration(seconds: 4));
    for (final digit in '$value'.split('')) {
      await tester.tap(find.byKey(keypadKeyKey(digit)));
      await tester.pump();
    }
    await tester.tap(find.byKey(keypadKeyKey('submit')));
    await tester.pump(const Duration(milliseconds: 700));
  }

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('a duel: lanes, result, rematch — $name', (tester) async {
      await pumpDuel(tester, theme);
      expect(find.text('Finding an opponent…'), findsOneWidget);
      await tester.pump();
      expect(find.text('1 / 8'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);

      for (final value in answers.take(4)) {
        await type(tester, value);
      }
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('5 / 8'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/duel_$name.png'),
      );

      for (final value in answers.skip(4)) {
        await type(tester, value);
      }
      await tester.pump();
      await tester.pump();
      expect(find.text('Won'), findsOneWidget);
      expect(find.text('Basics · 1 542 → 1 560'), findsOneWidget);
      expect(find.text('8 / 8'), findsOneWidget);
      expect(find.text('5 / 8'), findsOneWidget);
      expect(client.submitted.single.$1, 'd1');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/duel_result_$name.png'),
      );

      await tester.tap(find.text('Rematch'));
      await tester.pump();
      await tester.pump();
      expect(client.finds.last.rematchOf, 'd1');
      expect(find.text('1 / 3'), findsOneWidget, reason: 'Get the count');
      expect(find.text('442'), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('42'), findsOneWidget, reason: 'her distance');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/duel_count_$name.png'),
      );
    });
  }

  testWidgets('a missed pattern question: its own Method, as in games', (
    tester,
  ) async {
    final offer = basicsOffer();
    final families = offer.config.questionFamilies();
    final missed = families.indexWhere((f) => f != null);
    expect(missed, isNot(-1), reason: 'the pinned duel has a pattern question');
    final question = offer.config.questions()[missed];
    await pumpDuel(tester, buildLightTheme());
    await tester.pump();
    for (final (i, value) in answers.indexed) {
      await type(tester, i == missed ? value + 1 : value);
      if (i == missed) await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    await tester.pump();
    final row = find.byKey(ValueKey('duel-mistake-$missed'));
    await tester.ensureVisible(row);
    await tester.tap(find.descendant(of: row, matching: find.text('Method')));
    await tester.pump();
    final method = methodFor(question, family: families[missed]);
    expect(method.family, families[missed]);
    expect(
      find.descendant(
        of: row,
        matching: find.text(methodName(method, question.type)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('✕ asks, then sends the run as it stands', (tester) async {
    await pumpDuel(tester, buildLightTheme());
    await tester.pump();
    await type(tester, answers.first);
    await tester.tap(find.byTooltip('Quit'));
    await tester.pump();
    expect(find.text('Quit the duel?'), findsOneWidget);
    await tester.tap(find.text('Quit'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Lost'), findsOneWidget, reason: '1 right against 5');
    final sent = client.submitted.single.$2 as QuizRun;
    expect(sent.answers.length, 8);
  });

  group('before the duel (Phase 6b commit 5, review M15)', () {
    testWidgets('a sleeping server: "Waking the server…" and Cancel, '
        'nothing asked', (tester) async {
      client = FakeDuelClient(offers: [basicsOffer()])
        ..asleep = Completer<void>();
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'device',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
        duelClient: client,
        duelRunStore: MemoryDuelRunStore(),
      ).forPlayer('me');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => playDuel(
                  context,
                  environment,
                  () => client.find(DuelMode.basics),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // The spinner never settles: the route's transition, then on.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Finding an opponent…'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.pump(DuelFlowScreen.slowWakeAfter);
      expect(find.text('Waking the server…'), findsOneWidget);
      expect(find.text('It can take up to a minute.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('open'), findsOneWidget, reason: 'closed');
      expect(find.text('Waking the server…'), findsNothing);
      // The server wakes after the player left: still nothing asked.
      client.asleep!.complete();
      await tester.pumpAndSettle();
      expect(client.finds, isEmpty);
    });

    testWidgets('once awake, the duel is asked for: no Cancel then', (
      tester,
    ) async {
      await pumpDuel(tester, buildLightTheme());
      await tester.pump();
      await tester.pump();
      expect(client.supportCalls, 1);
      expect(client.finds.single.mode, DuelMode.basics);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('1 / 8'), findsOneWidget);
    });

    testWidgets('a server that cannot be reached: said, nothing asked', (
      tester,
    ) async {
      final offline = FakeDuelClient()
        ..failure = const DuelUnavailable('offline');
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'device',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
        duelClient: offline,
        duelRunStore: MemoryDuelRunStore(),
      ).forPlayer('me');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: DuelFlowScreen(
            environment: environment,
            load: () => offline.find(DuelMode.basics),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Could not reach the server.'), findsOneWidget);
      expect(offline.finds, isEmpty);
    });
  });

  // Phase 6b commit 6 (review M17): a duel in play, the lanes over the game.
  testWidgets('accessibility guidelines in a duel', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpDuel(tester, buildLightTheme());
    await tester.pump();
    await tester.pump();
    expect(find.text('1 / 8'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a guest is told to save their progress', (tester) async {
    final guest = FakeDuelClient()..failure = const DuelAccountRequired();
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'device',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      duelClient: guest,
      duelRunStore: MemoryDuelRunStore(),
    ).forPlayer('me');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: DuelFlowScreen(
          environment: environment,
          load: () => guest.find(DuelMode.basics),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Save your progress to play online.'), findsOneWidget);
  });
}
