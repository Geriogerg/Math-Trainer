import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/beta_access.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_trainer/presentation/screens/auth_gate.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'kit_finders.dart';

/// Controllable — unlike `FakeAccountRepository`
/// (`test/fake_account_repository.dart`), which starts signed in and only
/// serves tests that do not care about the gate itself.
class _ControllableAccountRepository implements AccountRepository {
  @override
  Future<String?> accessToken() async => 'test-token';
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
  final _controller = StreamController<Account?>.broadcast();

  /// Simulates resolving the local session (persisted or absent) —
  /// `AuthGate` must never show the form before this resolution, so the
  /// gate does not flicker for a player already signed in.
  void resolveSession(Account? account) => _controller.add(account);

  @override
  Stream<Account?> get authState => _controller.stream;

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    final account = Account(id: 'user-$email', email: email);
    _controller.add(account);
    return account;
  }

  /// Anonymous sign-ins requested so far. Each stays pending until the
  /// test settles it ([completeAnonymous] / [failAnonymous]) — so tests
  /// that drive `resolveSession` by hand are not raced by a guest account.
  int anonymousSignIns = 0;
  Completer<Account>? _pendingAnonymous;

  @override
  Future<Account> signInAnonymously() {
    anonymousSignIns++;
    return (_pendingAnonymous = Completer<Account>()).future;
  }

  void completeAnonymous(Account account) {
    _pendingAnonymous!.complete(account);
    _controller.add(account);
  }

  void failAnonymous(AccountFailure failure) =>
      _pendingAnonymous!.completeError(AccountException(failure));

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }
}

const _guest = Account(id: 'guest-1', isAnonymous: true);

class _MemoryBetaStore implements BetaCodeStore {
  String? code;
  String? player;
  @override
  Future<String?> acceptedCode() async => code;
  @override
  Future<void> saveAcceptedCode(String value) async => code = value;
  @override
  Future<String?> redeemedFor() async => player;
  @override
  Future<void> markRedeemedFor(String playerId) async => player = playerId;
}

/// Knows one code, `ABCD2345`; records redeems.
class _FakeBetaCodes implements BetaCodeRepository {
  final redeemed = <String>[];
  @override
  Future<BetaCodeStatus> status(String code) async =>
      code == 'ABCD2345' ? BetaCodeStatus.ok : BetaCodeStatus.unknown;
  @override
  Future<BetaRedeemResult> redeem(String code) async {
    redeemed.add(code);
    return BetaRedeemResult.redeemed;
  }
}

/// Accepts everything; records the session ids it was sent.
class _RecordingUploadClient implements SessionUploadClient {
  final sent = <String>[];

  @override
  Future<UploadOutcome> upload(SessionUpload upload) async {
    sent.add(upload.session.id);
    return UploadAccepted(syncedAt: DateTime.utc(2026, 11, 20));
  }
}

void main() {
  // `PlayTab` reads the remembered selection before it draws (no flash of
  // the default selection).
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppEnvironment> pumpGate(
    WidgetTester tester,
    _ControllableAccountRepository accountRepository, {
    BetaCodeRepository? betaCodes,
    BetaCodeStore? betaCodeStore,
  }) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: accountRepository,
      profileRepository: FakeProfileRepository(),
      betaCodes: betaCodes,
      betaCodeStore: betaCodeStore ?? _MemoryBetaStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: AuthGate(environment: environment),
      ),
    );
    return environment;
  }

  testWidgets('shows a loading indicator until the local session is resolved', (
    tester,
  ) async {
    await pumpGate(tester, _ControllableAccountRepository());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Basics'), findsNothing);
  });

  testWidgets(
    'no session: creates an anonymous player and goes straight to the game, '
    'no form',
    (tester) async {
      final accountRepository = _ControllableAccountRepository();
      await pumpGate(tester, accountRepository);
      await tester.pump();

      accountRepository.resolveSession(null);
      await tester.pump();
      expect(accountRepository.anonymousSignIns, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      accountRepository.completeAnonymous(_guest);
      await tester.pumpAndSettle();

      expect(find.text('Basics'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('a returning player gets their account back, never a guest', (
    tester,
  ) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();

    accountRepository.resolveSession(
      const Account(id: 'returning', email: 'r@test.com'),
    );
    await tester.pumpAndSettle();

    expect(accountRepository.anonymousSignIns, 0);
    expect(find.text('Basics'), findsOneWidget);
  });

  testWidgets('repeated "no session" states start a single anonymous sign-in', (
    tester,
  ) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();

    accountRepository.resolveSession(null);
    await tester.pump();
    accountRepository.resolveSession(null);
    await tester.pump();

    expect(accountRepository.anonymousSignIns, 1);
  });

  testWidgets('first launch offline: a retry screen says why, then the game', (
    tester,
  ) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();
    accountRepository.resolveSession(null);
    await tester.pump();

    accountRepository.failAnonymous(AccountFailure.network);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't start"), findsOneWidget);
    expect(find.textContaining('No connection'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pump();
    expect(accountRepository.anonymousSignIns, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    accountRepository.completeAnonymous(_guest);
    await tester.pumpAndSettle();
    expect(find.text('Basics'), findsOneWidget);
  });

  testWidgets('rate limited: its own message', (tester) async {
    final accountRepository = _ControllableAccountRepository();
    await pumpGate(tester, accountRepository);
    await tester.pump();
    accountRepository.resolveSession(null);
    await tester.pump();

    accountRepository.failAnonymous(AccountFailure.rateLimited);
    await tester.pumpAndSettle();

    expect(find.textContaining('Too many new players'), findsOneWidget);
  });

  // Regression: `authState` returns a new `Stream` on each read. Read in
  // `build()`, every rebuild of the parent (day/night toggle) resubscribed
  // `StreamBuilder`, which went back through `waiting`: `AppShell` was
  // unmounted then recreated, and the current tab went back to Play.
  testWidgets("a parent rebuild keeps AppShell's state (current tab)", (
    tester,
  ) async {
    final environment = AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      accountRepository: FakeAccountRepository(),
      profileRepository: FakeProfileRepository(),
    );
    late StateSetter rebuildParent;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildParent = setState;
            return AuthGate(environment: environment);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    rebuildParent(() {});
    await tester.pump();

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the gate must not go back through the loading state',
    );
    await tester.pumpAndSettle();
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.selectedIndex, 2);
  });

  group('data bound to the account', () {
    // `PlayTab` reads the remembered selection along with the overall level:
    // without simulated preferences, that read fails and the screen stays on
    // the welcome text, whatever the history.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const accountA = Account(id: 'compte-a', email: 'a@test.com');
    const accountB = Account(id: 'compte-b', email: 'b@test.com');
    // The device's main level: addition 43, the three other basics at 0.
    // 43 / 4 = 10.75, shown as its whole part (Phase 6b commit 7, m3).
    const deviceMainLevel = 10;

    /// Game played under the device's local id (`test-player`, the one of
    /// `pumpGate`), as before accounts. Addition at level 43, the three
    /// other basics at 0: main level 43 / 4 = 10.75, shown as 10.
    Future<void> playOnDevice(AppEnvironment environment) =>
        environment.repository.recordSession(
          session: PersistedSession(
            id: 'session-appareil',
            playerId: environment.playerId,
            seed: 1,
            enabledTypes: const {ExerciseType.addition},
            exerciseCount: 4,
            totalScore: 100,
            levels: {ExerciseType.addition: Level.whole(40)},
            createdAt: DateTime.utc(2026, 11, 1),
          ),
          // Played to the end: a completed session.
          answers: [
            for (var i = 0; i < 4; i++)
              PersistedAnswer(
                id: 'answer-$i',
                sessionId: 'session-appareil',
                exerciseType: 'arithmetic',
                operationType: 'addition',
                operands: const {'left': 20, 'right': 22},
                submittedValue: 42,
                isCorrect: true,
                elapsedMs: 1500,
                createdAt: DateTime.utc(2026, 11, 1),
              ),
          ],
          levelUpdates: {
            ExerciseType.addition: LevelCacheEntry(
              level: Level.whole(43),
              sessionsPlayed: 1,
              updatedAt: DateTime.utc(2026, 11, 1),
            ),
          },
        );

    testWidgets(
      "the device's games go to the first account that signs in, not the next one",
      (tester) async {
        final accountRepository = _ControllableAccountRepository();
        final environment = await pumpGate(tester, accountRepository);
        await playOnDevice(environment);

        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(findLevelBadge(deviceMainLevel), findsOneWidget);

        // Signed out: a guest is being created (pending) — a spinner,
        // which never settles.
        accountRepository.resolveSession(null);
        await tester.pump();
        accountRepository.resolveSession(accountB);
        await tester.pumpAndSettle();
        expect(findLevelBadge(deviceMainLevel), findsNothing);

        // Signed out: a guest is being created (pending) — a spinner,
        // which never settles.
        accountRepository.resolveSession(null);
        await tester.pump();
        accountRepository.resolveSession(accountA);
        await tester.pumpAndSettle();
        expect(findLevelBadge(deviceMainLevel), findsOneWidget);
      },
    );

    testWidgets('switching accounts without signing out starts afresh', (
      tester,
    ) async {
      final accountRepository = _ControllableAccountRepository();
      final environment = await pumpGate(tester, accountRepository);
      await playOnDevice(environment);
      accountRepository.resolveSession(accountA);
      await tester.pumpAndSettle();
      expect(findLevelBadge(deviceMainLevel), findsOneWidget);

      accountRepository.resolveSession(accountB);
      await tester.pumpAndSettle();

      expect(findLevelBadge(deviceMainLevel), findsNothing);
    });
  });

  testWidgets('at sign-in, pending sessions of the player are uploaded', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = InMemorySessionRepository();
    await repository.recordSession(
      session: PersistedSession(
        id: 'played-offline',
        playerId: _guest.id,
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 1,
        totalScore: 0,
        levels: {ExerciseType.addition: Level.zero},
        createdAt: DateTime.utc(2026, 11, 19),
        typeSequence: const [ExerciseType.addition],
        rulesVersion: RulesVersion.current,
      ),
      answers: const [],
      levelUpdates: const {},
    );
    final uploads = _RecordingUploadClient();
    final accountRepository = _ControllableAccountRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: AuthGate(
          environment: AppEnvironment(
            repository: repository,
            playerId: 'device-id',
            accountRepository: accountRepository,
            profileRepository: FakeProfileRepository(),
            uploadClient: uploads,
          ),
        ),
      ),
    );

    accountRepository.resolveSession(_guest);
    await tester.pumpAndSettle();

    expect(uploads.sent, ['played-offline']);
    expect(await repository.pendingUploads(_guest.id), isEmpty);
  });

  testWidgets('a guest replaced by another account is remembered as left', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final accountRepository = _ControllableAccountRepository();
    final environment = await pumpGate(tester, accountRepository);

    accountRepository.resolveSession(_guest);
    await tester.pumpAndSettle();
    // Signs in to an existing account from this guest (Profile).
    accountRepository.resolveSession(
      const Account(id: 'account-b', email: 'b@example.com'),
    );
    await tester.pumpAndSettle();

    final left = await environment.abandonedGuestStore.load();
    expect(left.keys, [_guest.id]);
  });

  group('beta gate (Phase 3a commit 3)', () {
    /// A pending anonymous sign-in shows a spinner that never settles.
    Future<void> settleWhileSigningIn(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('a new device is asked for a code before any guest exists', (
      tester,
    ) async {
      final accounts = _ControllableAccountRepository();
      final codes = _FakeBetaCodes();
      final store = _MemoryBetaStore();
      await pumpGate(tester, accounts, betaCodes: codes, betaCodeStore: store);
      accounts.resolveSession(null);
      await tester.pumpAndSettle();

      expect(find.text('Invitation code'), findsOneWidget);
      expect(accounts.anonymousSignIns, 0);

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('This code is not valid'), findsOneWidget);
      expect(accounts.anonymousSignIns, 0);

      // Lower case with a dash: the same code.
      await tester.enterText(find.byType(TextField), 'abcd-2345');
      await tester.tap(find.text('Continue'));
      await settleWhileSigningIn(tester);
      expect(store.code, 'ABCD2345');
      expect(accounts.anonymousSignIns, 1);

      accounts.completeAnonymous(_guest);
      await tester.pumpAndSettle();
      expect(find.text('Invitation code'), findsNothing);
      expect(codes.redeemed, ['ABCD2345']);
      expect(store.player, _guest.id);
    });

    testWidgets('a device that passed the gate is not asked again', (
      tester,
    ) async {
      final accounts = _ControllableAccountRepository();
      final store = _MemoryBetaStore()..code = 'ABCD2345';
      await pumpGate(
        tester,
        accounts,
        betaCodes: _FakeBetaCodes(),
        betaCodeStore: store,
      );
      accounts.resolveSession(null);
      await settleWhileSigningIn(tester);

      expect(find.text('Invitation code'), findsNothing);
      expect(accounts.anonymousSignIns, 1);
    });

    testWidgets('an existing account signs in without a code', (tester) async {
      final accounts = _ControllableAccountRepository();
      final codes = _FakeBetaCodes();
      await pumpGate(tester, accounts, betaCodes: codes);
      accounts.resolveSession(null);
      await tester.pumpAndSettle();

      await tester.tap(find.text('I already have an account'));
      await tester.pumpAndSettle();
      expect(find.text('Invitation code'), findsNothing);
      // The account arrives: the gate closes, no guest, no redeem.
      accounts.resolveSession(const Account(id: 'old', email: 'o@test.com'));
      await tester.pumpAndSettle();
      expect(accounts.anonymousSignIns, 0);
      expect(codes.redeemed, isEmpty);
    });

    testWidgets('without a gate in the build, nothing is asked', (
      tester,
    ) async {
      final accounts = _ControllableAccountRepository();
      await pumpGate(tester, accounts);
      accounts.resolveSession(null);
      await settleWhileSigningIn(tester);
      expect(find.text('Invitation code'), findsNothing);
      expect(accounts.anonymousSignIns, 1);
    });
  });
}
