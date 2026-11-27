import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/player_profile.dart';
import 'package:math_core/account/profile_repository.dart';
import 'package:math_trainer/core/state/account_form_controller.dart';

class _Accounts implements AccountRepository {
  @override
  Future<String?> accessToken() async => 'test-token';
  @override
  Future<void> deleteAccount() => throw UnimplementedError();
  AccountException? linkError;
  AccountException? signInError;
  bool pendingConfirmation = false;
  final linkCalls = <(String, String)>[];
  final ageDeclarations = <DateTime>[];
  final signInCalls = <(String, String)>[];

  @override
  Stream<Account?> get authState => const Stream.empty();

  @override
  Future<Account?> linkEmail({
    required String email,
    required String password,
    required DateTime ageDeclaredAt,
  }) async {
    linkCalls.add((email, password));
    ageDeclarations.add(ageDeclaredAt);
    if (linkError case final e?) throw e;
    if (pendingConfirmation) return null;
    return Account(id: 'guest', email: email);
  }

  final resendCalls = <String>[];

  @override
  Future<void> resendConfirmation({required String email}) async =>
      resendCalls.add(email);

  final resetCalls = <String>[];
  final passwords = <String>[];
  AccountException? passwordError;

  @override
  Future<void> requestPasswordReset({required String email}) async =>
      resetCalls.add(email);

  @override
  Future<void> setPassword({required String password}) async {
    if (passwordError case final e?) throw e;
    passwords.add(password);
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls.add((email, password));
    if (signInError case final e?) throw e;
    return Account(id: 'other', email: email);
  }

  @override
  Future<Account> signInAnonymously() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

class _Profiles implements ProfileRepository {
  bool fails = false;
  final names = <String>[];

  @override
  Future<PlayerProfile> currentProfile() => throw UnimplementedError();

  @override
  Future<void> updateDisplayName(String displayName) async {
    if (fails) throw Exception('offline');
    names.add(displayName);
  }
}

void main() {
  late _Accounts accounts;
  late _Profiles profiles;
  late AccountFormController controller;

  setUp(() {
    accounts = _Accounts();
    profiles = _Profiles();
    controller = AccountFormController(
      accounts: accounts,
      profiles: profiles,
      clock: () => DateTime.utc(2026, 11, 27, 9, 30),
    );
  });

  group('saveProgress', () {
    test(
      'links the trimmed email and the password, then saves the name',
      () async {
        final outcome = await controller.saveProgress(
          email: ' me@test.com ',
          password: 'secret-1',
          displayName: '  Alex ',
          ageConfirmed: true,
        );

        expect(outcome, SaveProgressOutcome.saved);
        expect(accounts.linkCalls, [('me@test.com', 'secret-1')]);
        expect(profiles.names, ['Alex']);
        expect(controller.isSubmitting, isFalse);
        expect(controller.failure, isNull);
      },
    );

    // Phase 6c commit 2 (plan v4.1; review B1): the minimum age, declared.
    test('"I am 15 or older" unticked sends nothing; ticked, its moment goes '
        'with the email', () async {
      final refused = await controller.saveProgress(
        email: 'me@test.com',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: false,
      );
      expect(refused, SaveProgressOutcome.failed);
      expect(controller.problem, AccountFormProblem.ageNotConfirmed);
      expect(accounts.linkCalls, isEmpty);

      await controller.saveProgress(
        email: 'me@test.com',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: true,
      );
      expect(accounts.ageDeclarations, [DateTime.utc(2026, 11, 27, 9, 30)]);
    });

    test('a missing field sends nothing', () async {
      for (final (email, password, name) in [
        ('', 'p', 'n'),
        ('e@x.com', '', 'n'),
        ('e@x.com', 'p', '   '),
      ]) {
        final outcome = await controller.saveProgress(
          email: email,
          password: password,
          displayName: name,
          ageConfirmed: true,
        );
        expect(outcome, SaveProgressOutcome.failed);
        expect(controller.problem, AccountFormProblem.missingFields);
      }
      expect(accounts.linkCalls, isEmpty);
    });

    test('a name over the limit sends nothing', () async {
      final outcome = await controller.saveProgress(
        email: 'e@x.com',
        password: 'p',
        displayName: 'x' * (maxDisplayNameLength + 1),
        ageConfirmed: true,
      );
      expect(outcome, SaveProgressOutcome.failed);
      expect(controller.problem, AccountFormProblem.invalidName);
      expect(controller.nameProblem, DisplayNameProblem.tooLong);
      expect(accounts.linkCalls, isEmpty);
    });

    test('a name the rule refuses sends nothing (Phase 2 commit 9)', () async {
      for (final (name, problem) in [
        ('李雷', DisplayNameProblem.charset),
        ('Big Fucker', DisplayNameProblem.blocked),
      ]) {
        final outcome = await controller.saveProgress(
          email: 'e@x.com',
          password: 'p',
          displayName: name,
          ageConfirmed: true,
        );
        expect(outcome, SaveProgressOutcome.failed);
        expect(controller.nameProblem, problem);
      }
      expect(accounts.linkCalls, isEmpty);
    });

    test('email already used: failure kept, no name saved', () async {
      accounts.linkError = const AccountException(
        AccountFailure.emailAlreadyUsed,
      );

      final outcome = await controller.saveProgress(
        email: 'taken@test.com',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: true,
      );

      expect(outcome, SaveProgressOutcome.failed);
      expect(controller.failure, AccountFailure.emailAlreadyUsed);
      expect(profiles.names, isEmpty);
      expect(controller.isSubmitting, isFalse);
    });

    test('linked but the name fails: the progress is still saved', () async {
      profiles.fails = true;

      final outcome = await controller.saveProgress(
        email: 'me@test.com',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: true,
      );

      expect(outcome, SaveProgressOutcome.savedWithoutName);
      expect(controller.failure, isNull);
    });

    // Phase 6c commit 3: the name is saved while the link waits, and the
    // link can be sent again.
    test('confirmation required: pending, the name saved, the link sent '
        'again', () async {
      accounts.pendingConfirmation = true;

      final outcome = await controller.saveProgress(
        email: ' me@test.com ',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: true,
      );

      expect(outcome, SaveProgressOutcome.confirmationPending);
      expect(profiles.names, ['Alex']);
      expect(controller.pendingEmail, 'me@test.com');
      expect(controller.resent, isFalse);
      expect(await controller.resendConfirmation(), isTrue);
      expect(accounts.resendCalls, ['me@test.com']);
      expect(controller.resent, isTrue);
    });

    test('a new attempt clears the previous failure', () async {
      accounts.linkError = const AccountException(AccountFailure.network);
      await controller.saveProgress(
        email: 'me@test.com',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: true,
      );
      accounts.linkError = null;

      await controller.saveProgress(
        email: 'me@test.com',
        password: 'secret-1',
        displayName: 'Alex',
        ageConfirmed: true,
      );

      expect(controller.failure, isNull);
    });
  });

  group('signIn', () {
    test('success with trimmed email', () async {
      expect(
        await controller.signIn(email: ' me@test.com', password: 'pw'),
        isTrue,
      );
      expect(accounts.signInCalls, [('me@test.com', 'pw')]);
    });

    test('wrong credentials: false, failure kept', () async {
      accounts.signInError = const AccountException(
        AccountFailure.invalidCredentials,
      );
      expect(
        await controller.signIn(email: 'me@test.com', password: 'pw'),
        isFalse,
      );
      expect(controller.failure, AccountFailure.invalidCredentials);
    });

    test('missing field: nothing sent', () async {
      expect(await controller.signIn(email: '', password: 'pw'), isFalse);
      expect(controller.problem, AccountFormProblem.missingFields);
      expect(accounts.signInCalls, isEmpty);
    });
  });
}
