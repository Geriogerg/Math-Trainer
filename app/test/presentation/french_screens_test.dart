import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_exception.dart';
import 'package:math_core/feedback/feedback.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/hints.dart';
import 'package:math_trainer/presentation/screens/config_error_screen.dart';
import 'package:math_trainer/presentation/screens/password_screens.dart';
import 'package:math_trainer/presentation/screens/play_tab.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/screens/save_progress_screen.dart';
import 'package:math_trainer/presentation/screens/sign_in_screen.dart';
import 'package:math_trainer/presentation/screens/start_error_view.dart';
import 'package:math_trainer/presentation/strings/strings.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import '../fake_stores.dart';
import 'golden_test_utils.dart';

/// Phase 6d commit 5: the screens and dialogs the golden tests do not
/// render, in French at 360 px — the account forms, the start errors, the
/// first-run card and the challenges' rules, a guest's Profile and its
/// dialogs, feedback. Each fails on an overflow, a text cut short or an
/// English word, and is kept as `goldens/fr360_*.png` for a person to read.

/// The account forms' answers: an email waiting for its link, or taken.
class _Accounts extends FakeAccountRepository {
  _Accounts({this.taken = false}) : super(anonymous: true);

  final bool taken;

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
    required DateTime ageDeclaredAt,
    required String language,
  }) async {
    if (taken) {
      throw const AccountException(AccountFailure.emailAlreadyUsed);
    }
    return null;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<void> resendConfirmation({required String email}) async {}
}

class _Feedback implements FeedbackRepository {
  @override
  Future<FeedbackOutcome> send({
    required String message,
    required String appVersion,
  }) async => FeedbackOutcome.sent;
}

/// [screen] pushed over an empty page (its back arrow shows, as in the app).
Future<void> _pumpPushed(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: testLocale,
      supportedLocales: testLocales,
      localizationsDelegates: testLocalizations,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => screen)),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

Future<void> _pumpHome(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: testLocale,
      supportedLocales: testLocales,
      localizationsDelegates: testLocalizations,
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

AppEnvironment _environment({Set<Hint> seen = const {}, bool guest = true}) =>
    AppEnvironment(
      repository: InMemorySessionRepository(),
      playerId: 'p',
      accountRepository: FakeAccountRepository(anonymous: guest),
      profileRepository: FakeProfileRepository(),
      typeSelectionStore: FakeTypeSelectionStore(),
      gameSetupStore: FakeGameSetupStore(),
      chainSetupStore: FakeChainSetupStore(),
      tablesStore: FakeTablesStore(),
      hints: FakeHintsStore(seen),
      feedbackRepository: _Feedback(),
    );

void main() {
  setUpAll(loadInterFontForGoldens);
  setUp(useFrench);

  group('account', () {
    testWidgets('sign in — French, 360 px', (tester) async {
      await _pumpPushed(
        tester,
        SignInScreen(
          accountRepository: _Accounts(),
          profileRepository: FakeProfileRepository(),
          isGuest: true,
          guestHasProgress: true,
        ),
      );
      await expectFrenchAt360(tester, 'sign_in');
    });

    testWidgets('forgot password, the link sent — French, 360 px', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        ForgotPasswordScreen(
          accountRepository: _Accounts(),
          profileRepository: FakeProfileRepository(),
          initialEmail: 'moi@test.fr',
        ),
      );
      await expectFrenchAt360(tester, 'forgot_password');
      await tester.tap(find.text(strings.account.sendLink));
      await expectFrenchAt360(tester, 'forgot_password_sent');
    });

    testWidgets('set a new password — French, 360 px', (tester) async {
      await _pumpPushed(
        tester,
        SetPasswordScreen(
          accountRepository: _Accounts(),
          profileRepository: FakeProfileRepository(),
        ),
      );
      await expectFrenchAt360(tester, 'set_password');
    });

    testWidgets('save your progress: empty, then the age box — French, '
        '360 px', (tester) async {
      await _pumpPushed(
        tester,
        SaveProgressScreen(
          accountRepository: _Accounts(),
          profileRepository: FakeProfileRepository(),
          guestHasProgress: true,
        ),
      );
      await tester.tap(find.text(strings.account.save));
      await expectFrenchAt360(tester, 'save_progress_empty', height: 900);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'moi@test.fr');
      await tester.enterText(fields.at(1), 'secret-1');
      await tester.enterText(fields.at(2), 'Alex');
      await tester.tap(find.text(strings.account.save));
      await expectFrenchAt360(tester, 'save_progress_age', height: 900);
    });

    testWidgets('save your progress: check your inbox — French, 360 px', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        SaveProgressScreen(
          accountRepository: _Accounts(),
          profileRepository: FakeProfileRepository(),
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'moi@test.fr');
      await tester.enterText(fields.at(1), 'secret-1');
      await tester.enterText(fields.at(2), 'Alex');
      await tester.tap(find.text(strings.account.ageBox));
      await tester.tap(find.text(strings.account.save));
      await expectFrenchAt360(tester, 'check_inbox');
    });

    testWidgets('save your progress: the email is taken — French, 360 px', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        SaveProgressScreen(
          accountRepository: _Accounts(taken: true),
          profileRepository: FakeProfileRepository(),
          guestHasProgress: true,
        ),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'pris@test.fr');
      await tester.enterText(fields.at(1), 'secret-1');
      await tester.enterText(fields.at(2), 'Alex');
      await tester.tap(find.text(strings.account.ageBox));
      await tester.tap(find.text(strings.account.save));
      await expectFrenchAt360(tester, 'email_taken', height: 900);
    });
  });

  group('start', () {
    for (final failure in [
      AccountFailure.network,
      AccountFailure.rateLimited,
      AccountFailure.humanCheck,
    ]) {
      testWidgets('could not start, ${failure.name} — French, 360 px', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          Scaffold(
            body: StartErrorView(failure: failure, onRetry: () {}),
          ),
        );
        await expectFrenchAt360(tester, 'start_${failure.name}');
      });
    }

    testWidgets('the game could not start — French, 360 px', (tester) async {
      await tester.pumpWidget(
        ConfigErrorApp.startFailed(StateError('503'), onReload: () {}),
      );
      await expectFrenchAt360(tester, 'start_failed');
    });
  });

  group('play', () {
    testWidgets('a new guest: the first-run card, sign in — French, 360 px', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        Scaffold(body: PlayTab(environment: _environment())),
      );
      await expectFrenchAt360(tester, 'first_run', height: 1400);
    });

    // The card's name read when the test runs, in French.
    // Chain operations has a setup page; Get the count starts a round.
    for (final (name, label, next) in [
      ('chain', () => strings.home.chainOperations, 'chain_setup'),
      ('count', () => strings.home.getTheCount, 'count_start'),
    ]) {
      testWidgets('$name: its rules, then its setup — French, 360 px', (
        tester,
      ) async {
        await _pumpHome(
          tester,
          Scaffold(
            body: PlayTab(environment: _environment(seen: {Hint.firstRun})),
          ),
        );
        final card = find.text(label());
        await tester.ensureVisible(card);
        await tester.tap(card);
        await expectFrenchAt360(tester, '${name}_rules');
        await tester.tap(find.text(strings.common.ok));
        // A round's clock never settles; the setup page does.
        await expectFrenchAt360(tester, next, settle: name == 'chain');
      });
    }
  });

  group('profile', () {
    Future<void> pumpProfile(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpHome(
        tester,
        Scaffold(body: ProfileScreen(environment: _environment())),
      );
    }

    testWidgets("a guest's profile — French, 360 px", (tester) async {
      await pumpProfile(tester);
      await expectFrenchAt360(tester, 'profile_guest', height: 2600);
    });

    testWidgets('delete my data, asked first — French, 360 px', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text(strings.profile.deleteButton(guest: true)));
      await expectFrenchAt360(tester, 'delete_data');
    });

    testWidgets('send feedback — French, 360 px', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text(strings.profile.sendFeedback));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.profile.send));
      await expectFrenchAt360(tester, 'feedback');
    });
  });
}
