import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/presentation/screens/auth_form.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Records the credentials received and fails with [failure] if given.
class _RecordingAccountRepository implements AccountRepository {
  _RecordingAccountRepository({this.failure});

  final AccountFailure? failure;
  final signInCalls = <String>[];

  @override
  Stream<Account?> get authState => const Stream.empty();

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls.add(email);
    final failure = this.failure;
    if (failure != null) {
      throw AccountException(failure, detail: 'Raw server message');
    }
    return Account(id: 'id', email: email);
  }

  @override
  Future<Account?> signUp({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    AccountRepository repository,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: AuthForm(accountRepository: repository)),
      ),
    );
  }

  Future<void> submit(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
  }

  testWidgets(
    'a server refusal shows our own message, not the raw one',
    (tester) async {
      final repository = _RecordingAccountRepository(
        failure: AccountFailure.invalidCredentials,
      );
      await pumpForm(tester, repository);

      await submit(tester, email: 'player@test.com', password: 'faux');

      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(find.textContaining('Raw server message'), findsNothing);
    },
  );

  testWidgets('server unreachable: asks to check the connection', (
    tester,
  ) async {
    await pumpForm(
      tester,
      _RecordingAccountRepository(failure: AccountFailure.network),
    );

    await submit(tester, email: 'player@test.com', password: 'secret');

    expect(find.textContaining('Server unreachable'), findsOneWidget);
  });

  testWidgets('the email is sent without the spaces added by the keyboard', (
    tester,
  ) async {
    final repository = _RecordingAccountRepository();
    await pumpForm(tester, repository);

    await submit(tester, email: ' player@test.com ', password: 'secret');

    expect(repository.signInCalls, ['player@test.com']);
  });

  testWidgets('empty field: local message, no server call', (
    tester,
  ) async {
    final repository = _RecordingAccountRepository();
    await pumpForm(tester, repository);

    await submit(tester, email: '   ', password: 'secret');

    expect(repository.signInCalls, isEmpty);
    expect(find.text('Enter your email and password.'), findsOneWidget);
  });

  testWidgets('Enter in the password field submits the form', (tester) async {
    final repository = _RecordingAccountRepository();
    await pumpForm(tester, repository);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'player@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'secret',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(repository.signInCalls, ['player@test.com']);
  });
}
