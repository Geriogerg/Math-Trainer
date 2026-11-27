import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/leaderboard_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'package:math_trainer/presentation/strings/strings.dart';

import 'golden_test_utils.dart';

class _FixedLeaderboard implements LeaderboardRepository {
  @override
  Future<Standing> aroundMe(LeaderboardBoard board) async => Ranked(
    rank: 42,
    total: 310,
    topPercent: 14,
    level: Level.whole(39),
    neighbours: [
      for (final (i, name) in [
        'Zoé',
        'Marc-Antoine',
        null,
        'Ines',
        'Tom',
        'Ada',
        'Lucas',
        'Chloé',
        null,
        'Nina',
        'Hugo',
      ].indexed)
        LeaderboardEntry(
          playerId: 'player-$i',
          rank: 37 + i,
          name: name,
          level: Level.whole(40 - (i ~/ 3)),
          isMe: i == 5,
        ),
    ],
  );

  @override
  Future<List<LeaderboardEntry>> top(LeaderboardBoard board) async => const [];

  @override
  Future<void> reportName(String playerId) async {}
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('leaderboard, around me — $name', (tester) async {
      await setGoldenSurfaceSize(tester);
      await tester.pumpWidget(
        MaterialApp(
          locale: testLocale,
          supportedLocales: testLocales,
          localizationsDelegates: testLocalizations,
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Scaffold(
            body: SafeArea(
              child: LeaderboardScreen(
                environment: AppEnvironment(
                  repository: InMemorySessionRepository(),
                  playerId: 'me',
                  accountRepository: FakeAccountRepository(),
                  profileRepository: FakeProfileRepository(),
                  leaderboardRepository: _FixedLeaderboard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/leaderboard_$name.png'),
      );
    });
  }

  testWidgets('leaderboard, around me — French, 360 px', (tester) async {
    useFrench();
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        supportedLocales: testLocales,
        localizationsDelegates: testLocalizations,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        home: Scaffold(
          body: SafeArea(
            child: LeaderboardScreen(
              environment: AppEnvironment(
                repository: InMemorySessionRepository(),
                playerId: 'me',
                accountRepository: FakeAccountRepository(),
                profileRepository: FakeProfileRepository(),
                leaderboardRepository: _FixedLeaderboard(),
              ),
            ),
          ),
        ),
      ),
    );
    await expectFrenchAt360(tester, 'leaderboard', height: 1000);
  });

  testWidgets('report a name — French, 360 px', (tester) async {
    useFrench();
    await tester.pumpWidget(
      MaterialApp(
        locale: testLocale,
        supportedLocales: testLocales,
        localizationsDelegates: testLocalizations,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        home: Scaffold(
          body: SafeArea(
            child: LeaderboardScreen(
              environment: AppEnvironment(
                repository: InMemorySessionRepository(),
                playerId: 'me',
                accountRepository: FakeAccountRepository(),
                profileRepository: FakeProfileRepository(),
                leaderboardRepository: _FixedLeaderboard(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(strings.ranks.reportName).first);
    await expectFrenchAt360(tester, 'report_name');
  });
}
