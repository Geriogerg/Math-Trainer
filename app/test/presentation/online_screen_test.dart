import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_duel_client.dart';
import '../fake_profile_repository.dart';
import 'golden_test_utils.dart';

class FakeOnlineRepository implements OnlineRepository {
  FakeOnlineRepository(this.answer);

  OnlineOverview answer;
  int reads = 0;

  @override
  Future<OnlineOverview> overview() async {
    reads++;
    return answer;
  }
}

/// The mockup's screen 1: Basics 1 542, Advanced provisional, Get the
/// count 1 610; Léa's challenge waiting; Tom raced the player's run (won),
/// a practice duel lost.
OnlineOverview mockupOverview() => OnlineOverview.fromJson({
  'linked': true,
  'ratings': {
    'basics': {'rating': 1542.2, 'ratedDuels': 14},
    'advanced': {'rating': 1380.4, 'ratedDuels': 4},
    'count': {'rating': 1610.0, 'ratedDuels': 11},
  },
  'waiting': [
    {
      'duelId': 'w1',
      'mode': 'basics',
      'fromId': 'lea',
      'from': 'Léa',
      'expiresAt': '2099-01-01T00:00:00+00:00',
    },
  ],
  'recent': [
    {
      'duelId': 'r1',
      'mode': 'basics',
      'kind': 'pool',
      'at': '2026-11-25T09:00:00+00:00',
      'state': 'done',
      'raced': true,
      'opponentId': 'tom',
      'opponent': 'Tom',
      'result': 1,
      'rated': true,
    },
    {
      'duelId': 'r2',
      'mode': 'advanced',
      'kind': 'practice',
      'at': '2026-11-25T08:00:00+00:00',
      'state': 'done',
      'raced': false,
      'result': 0,
      'rated': false,
    },
  ],
});

void main() {
  setUpAll(loadInterFontForGoldens);

  late FakeOnlineRepository online;
  late FakeDuelClient client;

  Future<void> pumpShell(WidgetTester tester, ThemeData theme) async {
    await setGoldenSurfaceSize(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'device',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      onlineRepository: online,
      duelClient: client,
      duelRunStore: MemoryDuelRunStore(),
    ).forPlayer('me');
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: AppShell(environment: environment),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    online = FakeOnlineRepository(mockupOverview());
    client = FakeDuelClient(
      offers: [
        DuelOffer(
          duelId: 'w1',
          kind: DuelKind.challenge,
          config: DuelConfig(
            mode: DuelMode.basics,
            seed: 1,
            difficulty: 4,
            rulesVersion: RulesVersion.v8,
          ),
          lane: QuizLane([
            for (var i = 0; i < 8; i++) (elapsedMs: 5000, correct: true),
          ]),
          opponent: const DuelOpponent(id: 'lea', name: 'Léa'),
        ),
      ],
    );
  });

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('the Online tab, as in the mockup — $name', (tester) async {
      await pumpShell(tester, theme);
      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('1 542'), findsOneWidget);
      expect(find.text('1 380 ?'), findsOneWidget, reason: '4 rated duels');
      expect(find.text('1 610'), findsOneWidget);
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.text('Léa · Basics'), findsOneWidget);
      expect(find.text('Tom raced your run'), findsOneWidget);
      expect(find.text('won'), findsOneWidget);
      expect(find.text('Practice · Advanced'), findsOneWidget);
      expect(find.text('lost'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/online_$name.png'),
      );
    });
  }

  testWidgets('a challenge waiting: a badge on the tab', (tester) async {
    await pumpShell(tester, buildLightTheme());
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    online.answer = OnlineOverview.fromJson({
      'linked': true,
      'ratings': {},
      'waiting': [],
      'recent': [],
    });
    // Back to Play and to Online: read again, no badge.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Play'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    expect(online.reads, greaterThanOrEqualTo(2));
  });

  testWidgets('no rating yet: the start from levels, provisional', (
    tester,
  ) async {
    online.answer = OnlineOverview.fromJson({
      'linked': true,
      'ratings': {},
      'waiting': [],
      'recent': [],
    });
    await pumpShell(tester, buildLightTheme());
    // No level on this device: 900, 900, 1 300 — all "?".
    expect(find.text('900 ?'), findsNWidgets(2));
    expect(find.text('1 300 ?'), findsOneWidget);
  });

  testWidgets('Play on a waiting challenge opens it', (tester) async {
    await pumpShell(tester, buildLightTheme());
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('waiting-w1')),
        matching: find.text('Play'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('1 / 8'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
  });

  testWidgets('a guest is invited to save their progress', (tester) async {
    online.answer = OnlineOverview.guest;
    await pumpShell(tester, buildLightTheme());
    expect(find.text('Save your progress'), findsOneWidget);
    expect(find.text('Basics'), findsNothing);
  });
}
