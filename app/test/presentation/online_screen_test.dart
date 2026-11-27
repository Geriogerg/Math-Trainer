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
import 'package:math_trainer/core/state/hints.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';
import 'package:math_trainer/presentation/strings/strings.dart';

import '../fake_account_repository.dart';
import '../fake_duel_client.dart';
import '../fake_profile_repository.dart';
import '../fake_stores.dart';
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

  Future<void> pumpShell(
    WidgetTester tester,
    ThemeData theme, {
    HintsStore? hints,
  }) async {
    await setGoldenSurfaceSize(tester);
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'device',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
      onlineRepository: online,
      duelClient: client,
      duelRunStore: MemoryDuelRunStore(),
      hints: hints,
    ).forPlayer('me');
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        supportedLocales: testLocales,
        localizationsDelegates: testLocalizations,
        theme: theme,
        home: AppShell(environment: environment),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(strings.online.tabOnline));
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
      expect(find.text('1\u202f542'), findsOneWidget);
      expect(
        find.text('1\u202f380 ?'),
        findsOneWidget,
        reason: '4 rated duels',
      );
      expect(find.text('1\u202f610'), findsOneWidget);
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
    await tester.tap(find.text(strings.online.tabOnline));
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
    expect(find.text('1\u202f300 ?'), findsOneWidget);
  });

  testWidgets('Play on a waiting challenge opens it', (tester) async {
    await pumpShell(tester, buildLightTheme());
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('waiting-w1')),
        matching: find.text('Play'),
      ),
    );
    await tester.pumpAndSettle();
    // The rules first (Phase 6b commit 4, review M15), then the duel.
    expect(find.text('Leaving counts as a loss.'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(find.text('1 / 8'), findsOneWidget);
    expect(find.text('Léa'), findsOneWidget);
  });

  testWidgets('a mode says its rules before a rated duel: Cancel finds '
      'nothing, Start finds (Phase 6b commit 4, review M15)', (tester) async {
    await pumpShell(tester, buildLightTheme());
    // One line under each mode.
    expect(find.text('8 questions, 2 each of + − × ÷.'), findsOneWidget);
    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    expect(find.text('Basics duel'), findsOneWidget);
    expect(find.textContaining('both ratings move'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(client.finds, isEmpty);
    expect(find.text('Basics duel'), findsNothing);

    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(client.finds.map((f) => f.mode), [DuelMode.basics]);
  });

  testWidgets('the rules sheet once per mode, then the reminder line '
      '(plan v4.1)', (tester) async {
    final hints = FakeHintsStore();
    client.offers.add(client.offers.first);
    await pumpShell(tester, buildLightTheme(), hints: hints);
    expect(find.text('Rated · leaving counts as a loss'), findsOneWidget);

    // Cancel: nothing remembered, the sheet comes again.
    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    expect(find.text('Basics duel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(hints.seenHints, isEmpty);

    await tester.tap(find.text('Basics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(hints.seenHints, {Hint.duelRulesBasics});
    expect(client.finds.map((f) => f.mode), [DuelMode.basics]);
    Navigator.of(tester.element(find.byType(AppShell))).pop();
    await tester.pumpAndSettle();

    // The next Basics duel starts on the tap; Advanced still asks once.
    await tester.tap(find.text('Basics'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Basics duel'), findsNothing);
    expect(client.finds, hasLength(2));
    Navigator.of(tester.element(find.byType(AppShell))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Advanced duel'), findsOneWidget);
  });

  testWidgets("the reminder's link opens every mode's rules", (tester) async {
    await pumpShell(tester, buildLightTheme(), hints: FakeHintsStore());
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();
    expect(find.text('Duel rules'), findsOneWidget);
    expect(
      find.text('Basics: 8 questions, 2 each of + − × ÷.'),
      findsOneWidget,
    );
    expect(find.text('Leaving counts as a loss.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(client.finds, isEmpty);
  });

  // Phase 6b commit 6 (review M17): the Online tab against Flutter's own
  // guidelines, both themes.
  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('accessibility guidelines — $name', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShell(tester, theme);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  testWidgets('a guest is invited to save their progress', (tester) async {
    online.answer = OnlineOverview.guest;
    await pumpShell(tester, buildLightTheme());
    expect(find.text('Save your progress'), findsOneWidget);
    expect(find.text('Basics'), findsNothing);
  });

  testWidgets('the Online tab — French, 360 px', (tester) async {
    useFrench();
    await pumpShell(tester, buildLightTheme());
    await expectFrenchAt360(tester, 'online', height: 1300);
  });

  testWidgets("a mode's rules, and every mode's — French, 360 px", (
    tester,
  ) async {
    useFrench();
    await pumpShell(tester, buildLightTheme(), hints: FakeHintsStore());
    await tester.tap(find.text(strings.labels.duelMode(DuelMode.advanced)));
    await expectFrenchAt360(tester, 'duel_rules_advanced');
    await tester.tap(find.text(strings.common.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.online.rulesLink));
    await expectFrenchAt360(tester, 'duel_rules_all');
  });
}
