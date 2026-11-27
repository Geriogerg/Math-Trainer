import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/leaderboard/leaderboard.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/leaderboard_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';
import 'package:math_trainer/presentation/kit/kit.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'kit_finders.dart';

/// Answers per board from maps; counts calls; can fail.
class _FakeLeaderboard implements LeaderboardRepository {
  final standings = <LeaderboardBoard, Standing>{};
  final tops = <LeaderboardBoard, List<LeaderboardEntry>>{};
  bool failing = false;
  int calls = 0;
  final reported = <String>[];

  @override
  Future<void> reportName(String playerId) async {
    if (failing) throw Exception('offline');
    reported.add(playerId);
  }

  @override
  Future<Standing> aroundMe(LeaderboardBoard board) async {
    calls++;
    if (failing) throw Exception('offline');
    return standings[board] ??
        const NotRanked(reason: NotRankedReason.noSessions);
  }

  @override
  Future<List<LeaderboardEntry>> top(LeaderboardBoard board) async {
    if (failing) throw Exception('offline');
    return tops[board] ?? const [];
  }
}

LeaderboardEntry _entry(int rank, String? name, int level, {bool me = false}) =>
    LeaderboardEntry(
      playerId: 'id-$rank',
      rank: rank,
      name: name,
      level: Level.whole(level),
      isMe: me,
    );

void main() {
  late _FakeLeaderboard leaderboard;

  setUp(() => leaderboard = _FakeLeaderboard());

  Future<void> pump(
    WidgetTester tester, {
    bool isActive = true,
    bool guest = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: LeaderboardScreen(
            isActive: isActive,
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'me',
              accountRepository: FakeAccountRepository(anonymous: guest),
              profileRepository: FakeProfileRepository(),
              leaderboardRepository: leaderboard,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ranked: top %, rank, and the neighbours with me marked', (
    tester,
  ) async {
    leaderboard.standings[const LeaderboardBoard.main()] = Ranked(
      rank: 8,
      total: 10,
      topPercent: 80,
      level: Level.whole(24),
      neighbours: [
        _entry(7, 'Bea', 32),
        _entry(8, 'Ada', 24, me: true),
        _entry(9, null, 16),
      ],
    );
    await pump(tester);

    expect(find.text('Top 80 %'), findsOneWidget);
    expect(find.text('Rank 8 of 10 · level 24'), findsOneWidget);
    expect(find.text('Ada (You)'), findsOneWidget);
    expect(find.text('Bea'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget); // no name chosen
  });

  testWidgets('board chips stay on one line on a phone (Phase 3a commit 0)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(tester);
    final chips = find.byType(TypeChip);
    expect(chips, findsNWidgets(LeaderboardBoard.all.length));
    final top = tester.getTopLeft(chips.first).dy;
    for (final element in chips.evaluate()) {
      expect(tester.getTopLeft(find.byWidget(element.widget)).dy, top);
    }
    // The last board is reachable by scrolling sideways.
    await tester.ensureVisible(find.text('Percentages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Percentages'));
    await tester.pumpAndSettle();
    final selected = tester.widget<TypeChip>(
      find.widgetWithText(TypeChip, 'Percentages'),
    );
    expect(selected.selected, isTrue);
  });

  // Phase 6b commit 6 (review M17).
  testWidgets('accessibility guidelines on Ranks', (tester) async {
    leaderboard.standings[const LeaderboardBoard.main()] = Ranked(
      rank: 8,
      total: 10,
      topPercent: 80,
      level: Level.whole(24),
      neighbours: [
        _entry(7, 'Bea', 32),
        _entry(8, 'Ada', 24, me: true),
        _entry(9, null, 16),
      ],
    );
    final handle = tester.ensureSemantics();
    await pump(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('top 100 view, and an empty board says so', (tester) async {
    leaderboard.tops[const LeaderboardBoard.main()] = [
      _entry(1, 'Zoe', 61),
      _entry(2, 'Max', 55),
    ];
    await pump(tester);
    await tester.tap(find.text('Top 100'));
    await tester.pumpAndSettle();
    expect(find.text('Zoe'), findsOneWidget);
    expect(findLevelBadge(61), findsOneWidget);

    await tester.ensureVisible(find.text('Division')); // one sideways line
    await tester.tap(find.text('Division'));
    await tester.pumpAndSettle();
    expect(find.text('Nobody on this board yet.'), findsOneWidget);
  });

  testWidgets('not ranked: why, and how many games are missing', (
    tester,
  ) async {
    leaderboard.standings[const LeaderboardBoard.of(
      ExerciseType.multiplication,
    )] = const NotRanked(
      reason: NotRankedReason.notEnoughSessions,
      sessionsNeeded: 2,
    );
    await pump(tester);
    expect(find.textContaining('Play a game to join'), findsOneWidget);

    await tester.ensureVisible(
      find.text('Multiplication'),
    ); // one sideways line
    await tester.tap(find.text('Multiplication'));
    await tester.pumpAndSettle();
    expect(
      find.text('2 more games with multiplication to join this board.'),
      findsOneWidget,
    );
  });

  testWidgets('offline: a message and Retry', (tester) async {
    leaderboard.failing = true;
    await pump(tester);
    expect(find.text('Could not load the leaderboard.'), findsOneWidget);

    leaderboard.failing = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load the leaderboard.'), findsNothing);
  });

  testWidgets('shown again: reloads', (tester) async {
    await pump(tester, isActive: false);
    final before = leaderboard.calls;
    await pump(tester);
    expect(leaderboard.calls, before + 1);
  });

  testWidgets('without a repository: says it is unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: LeaderboardScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'me',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('not available'), findsOneWidget);
  });

  testWidgets('report a name: confirm, sent, thanked; not mine, not "Player"', (
    tester,
  ) async {
    leaderboard.standings[const LeaderboardBoard.main()] = Ranked(
      rank: 2,
      total: 3,
      topPercent: 67,
      level: Level.whole(20),
      neighbours: [
        _entry(1, 'Rude Name', 30),
        _entry(2, 'Ada', 20, me: true),
        _entry(3, null, 10),
      ],
    );
    await pump(tester);

    // One report button: the named other player only.
    expect(find.byTooltip('Report name'), findsOneWidget);
    await tester.tap(find.byTooltip('Report name'));
    await tester.pumpAndSettle();
    expect(find.text('Report "Rude Name"?'), findsOneWidget);

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(leaderboard.reported, ['id-1']);
    expect(find.text('Reported — thank you.'), findsOneWidget);
  });

  // Phase 6a commit 4 (plan v3.9): only a saved account reports a name.
  testWidgets('a guest is told to save their progress; nothing is sent', (
    tester,
  ) async {
    leaderboard.tops[const LeaderboardBoard.main()] = [
      _entry(1, 'Rude Name', 30),
    ];
    await pump(tester, guest: true);
    await tester.tap(find.text('Top 100'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Report name'));
    await tester.pumpAndSettle();
    expect(find.text('Report "Rude Name"?'), findsNothing);
    expect(find.text('Save your progress to report a name.'), findsOneWidget);
    expect(leaderboard.reported, isEmpty);
  });

  testWidgets('a guest is offered to save their progress (Phase 2 commit 10)', (
    tester,
  ) async {
    leaderboard.standings[const LeaderboardBoard.main()] = const NotRanked(
      reason: NotRankedReason.notLinked,
    );
    await pump(tester);

    expect(
      find.textContaining('shows players who saved their progress'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save your progress'));
    await tester.pumpAndSettle();
    // The same screen as from Profile: email, password, player name.
    expect(find.text('Email'), findsOneWidget);
  });
}
