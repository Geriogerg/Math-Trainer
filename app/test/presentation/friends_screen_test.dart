import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/online_overview.dart';
import 'package:math_core/friends/friends.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/sharing/link_sharer.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/screens/friends_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_duel_client.dart';
import '../fake_profile_repository.dart';
import 'golden_test_utils.dart';
import 'online_screen_test.dart' show FakeOnlineRepository;

class FakeFriendsRepository implements FriendsRepository {
  final requested = <String>[];
  final responded = <(String, bool)>[];
  final removed = <String>[];
  var incomingRequests = <FriendRequest>[];
  var friendsList = const [
    Friend(id: 'lea', name: 'Léa', wins: 3, losses: 2),
    Friend(id: 'tom', name: 'Tom', wins: 1, losses: 4),
    Friend(id: 'ines', name: 'Inès'),
  ];
  FriendRequestOutcome next = FriendRequestOutcome.sent;

  @override
  Future<String> myCode() async => 'MATH-7K2P-QX4M';

  var newCodes = 0;

  @override
  Future<String> newCode() async => 'MATH-NEW${++newCodes}-QX4M';

  @override
  Future<FriendRequestOutcome> request(String code) async {
    requested.add(code);
    return next;
  }

  @override
  Future<List<FriendRequest>> incoming() async => incomingRequests;

  /// Thrown by respond and remove while set (offline).
  Exception? failure;

  @override
  Future<void> respond(String fromId, {required bool accept}) async {
    if (failure case final f?) throw f;
    responded.add((fromId, accept));
    incomingRequests = [];
  }

  @override
  Future<void> remove(String friendId) async {
    if (failure case final f?) throw f;
    removed.add(friendId);
  }

  @override
  Future<List<Friend>> friends() async => friendsList;

  @override
  Future<List<FriendDuel>> history(String friendId) async => [
    FriendDuel(
      duelId: 'h1',
      mode: DuelMode.basics,
      at: DateTime.utc(2026, 11, 24, 12),
      result: 1,
      you: const DuelScore(mode: DuelMode.basics, points: 7, totalMs: 38000),
      them: const DuelScore(mode: DuelMode.basics, points: 6, totalMs: 31000),
    ),
  ];
}

class FakeSharer implements LinkSharer {
  FakeSharer({required this.available});

  final bool available;
  final shared = <Uri>[];

  @override
  Future<bool> share({required String title, required Uri link}) async {
    if (available) shared.add(link);
    return available;
  }
}

class MemoryInviteStore implements PendingInviteStore {
  String? code;

  @override
  Future<String?> load() async => code;

  @override
  Future<void> save(String? code) async => this.code = code;
}

void main() {
  setUpAll(loadInterFontForGoldens);

  late FakeFriendsRepository friends;
  late FakeDuelClient client;
  late MemoryInviteStore invites;

  AppEnvironment environment({OnlineRepository? online, LinkSharer? sharer}) =>
      AppEnvironment(
        linkSharer: sharer,
        repository: InMemorySessionRepository(),
        playerId: 'device',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
        friendsRepository: friends,
        onlineRepository: online,
        pendingInviteStore: invites,
        duelClient: client,
        duelRunStore: MemoryDuelRunStore(),
        siteUrl: Uri.parse('https://math-trainer-kjc.pages.dev/'),
      ).forPlayer('me');

  Future<void> pumpFriends(
    WidgetTester tester,
    ThemeData theme, {
    LinkSharer? sharer,
  }) async {
    await setGoldenSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: FriendsScreen(environment: environment(sharer: sharer)),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    friends = FakeFriendsRepository();
    invites = MemoryInviteStore();
    client = FakeDuelClient(
      offers: [
        DuelOffer(
          duelId: 'c1',
          kind: DuelKind.challenge,
          config: DuelConfig(
            mode: DuelMode.advanced,
            seed: 7,
            difficulty: 4,
            rulesVersion: RulesVersion.v8,
          ),
          opponent: const DuelOpponent(id: 'lea', name: 'Léa'),
        ),
      ],
    );
  });

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('the Friends page, as in the mockup — $name', (tester) async {
      await pumpFriends(tester, theme);
      expect(find.text('MATH-7K2P-QX4M'), findsOneWidget);
      expect(find.text('Share link'), findsOneWidget);
      expect(find.text('Add code'), findsOneWidget);
      expect(find.text('Challenge'), findsNWidgets(3));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/friends_$name.png'),
      );
    });
  }

  testWidgets('Add code: normalised, sent, said', (tester) async {
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.text('Add code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' math 2b3c 4d5e ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(friends.requested, ['MATH-2B3C-4D5E']);
    expect(find.text('Request sent.'), findsOneWidget);
  });

  // Phase 6a (review m7): a player can replace a code shared too widely.
  testWidgets('New code: asked first, then shown', (tester) async {
    await pumpFriends(tester, buildLightTheme());
    await tester.ensureVisible(find.text('New code'));
    await tester.tap(find.text('New code'));
    await tester.pumpAndSettle();
    expect(find.text('Get a new code?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(friends.newCodes, 0);
    await tester.tap(find.text('New code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New code').last);
    await tester.pumpAndSettle();
    expect(friends.newCodes, 1);
    expect(find.text('MATH-NEW1-QX4M'), findsOneWidget);
  });

  testWidgets('a code that cannot be one is never sent', (tester) async {
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.text('Add code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'MATH-0O1I-2345');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(friends.requested, isEmpty);
    expect(find.text('No player has this code.'), findsOneWidget);
  });

  testWidgets('Share link copies the invite link', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://math-trainer-kjc.pages.dev/?friend=MATH-7K2P-QX4M');
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets('Share link: the share sheet where there is one', (tester) async {
    var copied = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = true;
        return null;
      },
    );
    final sheet = FakeSharer(available: true);
    await pumpFriends(tester, buildLightTheme(), sharer: sheet);
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(
      sheet.shared.single.toString(),
      'https://math-trainer-kjc.pages.dev/?friend=MATH-7K2P-QX4M',
    );
    expect(copied, isFalse);
    expect(find.text('Link copied'), findsNothing);
  });

  testWidgets('no share sheet (a desktop browser): copied instead', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpFriends(
      tester,
      buildLightTheme(),
      sharer: FakeSharer(available: false),
    );
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://math-trainer-kjc.pages.dev/?friend=MATH-7K2P-QX4M');
    expect(find.text('Link copied'), findsOneWidget);
  });

  // Phase 6b commit 6 (review M17).
  testWidgets('accessibility guidelines on Friends', (tester) async {
    friends.incomingRequests = [
      FriendRequest(fromId: 'zoe', name: 'Zoé', at: DateTime.utc(2026)),
    ];
    final handle = tester.ensureSemantics();
    await pumpFriends(tester, buildDarkTheme());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('a request: Accept makes friends', (tester) async {
    friends.incomingRequests = [
      FriendRequest(fromId: 'zoe', name: 'Zoé', at: DateTime.utc(2026)),
    ];
    await pumpFriends(tester, buildLightTheme());
    expect(find.text('Requests'), findsOneWidget);
    expect(find.text('Zoé'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(friends.responded, [('zoe', true)]);
    expect(find.text('Requests'), findsNothing);
  });

  testWidgets('a request that does not go through says so (Phase 6b '
      'commit 5, review M18)', (tester) async {
    friends.incomingRequests = [
      FriendRequest(fromId: 'zoe', name: 'Zoé', at: DateTime.utc(2026)),
    ];
    friends.failure = Exception('offline');
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();
    expect(find.text(friendActionFailedText), findsOneWidget);
    // Still there, to try again.
    expect(find.text('Zoé'), findsOneWidget);
  });

  testWidgets('a removal that does not go through: the page stays, and '
      'says so', (tester) async {
    friends.failure = Exception('offline');
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.byKey(const ValueKey('friend-lea')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove friend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text(friendActionFailedText), findsOneWidget);
    expect(find.text('Remove friend'), findsOneWidget, reason: 'not closed');
    expect(friends.removed, isEmpty);
  });

  testWidgets('Challenge: pick a mode, play first', (tester) async {
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.text('Challenge').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    // The rules first (Phase 6b commit 5).
    expect(find.text('Advanced duel'), findsOneWidget);
    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.pump();
    expect(client.finds.single.challenge, 'lea');
    expect(client.finds.single.mode, DuelMode.advanced);
    expect(find.text('1 / 8'), findsOneWidget);
    // Nobody to race yet: the player's lane only.
    expect(find.text('You'), findsOneWidget);
    expect(find.byKey(const ValueKey('lane-them')), findsNothing);
  });

  testWidgets('a friend\'s history; Remove friend after a confirmation', (
    tester,
  ) async {
    await pumpFriends(tester, buildLightTheme());
    await tester.tap(find.byKey(const ValueKey('friend-lea')));
    await tester.pumpAndSettle();
    expect(find.text('3–2'), findsOneWidget);
    expect(find.textContaining('Basics · 7–6'), findsOneWidget);
    expect(find.text('won'), findsOneWidget);
    await tester.tap(find.text('Remove friend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(friends.removed, ['lea']);
    expect(
      find.text('MATH-7K2P-QX4M'),
      findsOneWidget,
      reason: 'back on Friends',
    );
  });

  testWidgets('an invite link becomes a request once linked; the pill', (
    tester,
  ) async {
    invites.code = 'MATH-9XYZ-9XYZ';
    final online = FakeOnlineRepository(
      OnlineOverview.fromJson({
        'linked': true,
        'ratings': {},
        'waiting': [],
        'recent': [],
        'friendRequests': 1,
      }),
    );
    await setGoldenSurfaceSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: AppShell(environment: environment(online: online)),
      ),
    );
    await tester.pumpAndSettle();
    // Phase 6a: a link alone sends nothing; the player is asked.
    expect(friends.requested, isEmpty);
    expect(find.text('Send a friend request?'), findsOneWidget);
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(friends.requested, ['MATH-9XYZ-9XYZ']);
    expect(invites.code, isNull, reason: 'sent once');
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    expect(find.text('Friends'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Friends, 1 request'),
      findsOneWidget,
      reason: 'the dot, in words',
    );
    await tester.tap(find.byKey(const ValueKey('friends-pill')));
    await tester.pumpAndSettle();
    expect(find.text('MATH-7K2P-QX4M'), findsOneWidget);
  });
}
