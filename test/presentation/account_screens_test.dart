import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/core/state/account_form_controller.dart';
import 'package:math_trainer/presentation/screens/save_progress_screen.dart';
import 'package:math_trainer/presentation/screens/sign_in_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_profile_repository.dart';

class _Accounts implements AccountRepository {
  AccountException? linkError;
  int signIns = 0;

  @override
  Stream<Account?> get authState => const Stream.empty();

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
  }) async {
    if (linkError case final e?) throw e;
    return Account(id: 'guest', email: email);
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    signIns++;
    return Account(id: 'other', email: email);
  }

  @override
  Future<Account> signInAnonymously() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

void main() {
  /// A home screen that pushes [screen] and records what it pops with.
  Future<List<Object?>> pumpPushed(WidgetTester tester, Widget screen) async {
    final popped = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.of(
                    context,
                  ).push<Object?>(MaterialPageRoute(builder: (_) => screen));
                  popped.add(result);
                },
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    return popped;
  }

  Future<void> fillSaveForm(WidgetTester tester, String email) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'secret-1');
    await tester.enterText(fields.at(2), 'Alex');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('Save your progress: success pops with "saved"', (tester) async {
    final popped = await pumpPushed(
      tester,
      SaveProgressScreen(
        accountRepository: _Accounts(),
        profileRepository: FakeProfileRepository(),
      ),
    );

    await fillSaveForm(tester, 'me@test.com');

    expect(popped, [SaveProgressOutcome.saved]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets(
    'email already used: says so, then offers to sign in to that account '
    'with the replacement warning',
    (tester) async {
      final accounts = _Accounts()
        ..linkError = const AccountException(AccountFailure.emailAlreadyUsed);
      await pumpPushed(
        tester,
        SaveProgressScreen(
          accountRepository: accounts,
          profileRepository: FakeProfileRepository(),
          guestHasProgress: true,
        ),
      );

      await fillSaveForm(tester, 'taken@test.com');
      expect(
        find.text('An account already exists with this email.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sign in to that account instead'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.textContaining('will be replaced'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'taken@test.com',
      );
      expect(
        find.widgetWithText(FilledButton, 'Sign in and replace guest progress'),
        findsOneWidget,
      );
    },
  );

  testWidgets('a missing field is reported, nothing sent', (tester) async {
    await pumpPushed(
      tester,
      SaveProgressScreen(
        accountRepository: _Accounts(),
        profileRepository: FakeProfileRepository(),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter an email, a password and a player name.'),
      findsOneWidget,
    );
  });

  testWidgets('sign-in: success closes back to the first route', (
    tester,
  ) async {
    final accounts = _Accounts();
    await pumpPushed(
      tester,
      SignInScreen(
        accountRepository: accounts,
        profileRepository: FakeProfileRepository(),
        isGuest: false,
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'me@test.com');
    await tester.enterText(find.byType(TextField).at(1), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(accounts.signIns, 1);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a guest who never played gets no warning', (tester) async {
    await pumpPushed(
      tester,
      SignInScreen(
        accountRepository: _Accounts(),
        profileRepository: FakeProfileRepository(),
        isGuest: true,
      ),
    );

    expect(find.textContaining('will be replaced'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
