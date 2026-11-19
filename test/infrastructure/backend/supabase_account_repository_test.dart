import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:math_trainer/core/domain/account/account.dart';
import 'package:math_trainer/core/domain/account/account_repository.dart';
import 'package:math_trainer/infrastructure/backend/supabase_account_repository.dart';

import 'supabase_test_client.dart';

const _account = Account(id: testUserId, email: testEmail);

void main() {
  late SupabaseTestClient supabase;
  late SupabaseAccountRepository repository;

  setUp(() {
    supabase = SupabaseTestClient();
    repository = SupabaseAccountRepository(supabase.client);
  });

  tearDown(() => supabase.client.dispose());

  test('authState emits null at start without a session', () async {
    supabase.emitInitialSessionWithoutUser();
    expect(await repository.authState.first, isNull);
  });

  // Library guard: `ProfileScreen` reads the account through
  // `authState.first`. That only holds because `onAuthStateChange` replays
  // the latest event only (not the whole history, despite the name
  // `ReplaySubject`). If a Supabase update changed this, `.first` would
  // return `initialSession` (no account) after any sign-in made during the
  // current launch.
  test(
    'authState.first gives the current account after a sign-in made during this launch',
    () async {
      supabase.emitInitialSessionWithoutUser();
      await supabase.signIn();

      expect(await repository.authState.first, _account);
    },
  );

  test(
    'a new subscriber does not replay the signed-out state from history',
    () async {
      supabase.emitInitialSessionWithoutUser();
      await supabase.signIn();

      final emitted = <Account?>[];
      final subscription = repository.authState.listen(emitted.add);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emitted, [_account]);
    },
  );

  test('authState follows sign-in then sign-out', () async {
    supabase.emitInitialSessionWithoutUser();
    final emitted = <Account?>[];
    final subscription = repository.authState.listen(emitted.add);
    await pumpEventQueue();

    await supabase.signIn();
    await pumpEventQueue();
    await repository.signOut();
    await pumpEventQueue();
    await subscription.cancel();

    expect(emitted, [null, _account, null]);
  });

  test('offline sign-out: signed out locally, without an error', () async {
    final offlineLogout = SupabaseTestClient(
      authHandler: (request) async => request.url.path == '/auth/v1/logout'
          ? throw http.ClientException('Failed host lookup')
          : null,
    );
    addTearDown(offlineLogout.client.dispose);
    final repo = SupabaseAccountRepository(offlineLogout.client);
    await offlineLogout.signIn();

    await repo.signOut();

    expect(await repo.authState.first, isNull);
  });

  test(
    'signInAnonymously: a guest account (no email, anonymous), then emitted',
    () async {
      final anonymous = SupabaseTestClient(
        authHandler: (request) async => request.url.path == '/auth/v1/signup'
            ? http.Response(
                jsonEncode(anonymousSessionJson()),
                200,
                headers: {'content-type': 'application/json'},
              )
            : null,
      );
      addTearDown(anonymous.client.dispose);
      final repo = SupabaseAccountRepository(anonymous.client);
      anonymous.emitInitialSessionWithoutUser();

      final account = await repo.signInAnonymously();

      const guest = Account(id: testUserId, isAnonymous: true);
      expect(account, guest);
      expect(await repo.authState.first, guest);
    },
  );

  test('an email account is not anonymous', () async {
    supabase.emitInitialSessionWithoutUser();
    await supabase.signIn();

    final account = await repository.authState.first;
    expect(account?.isAnonymous, isFalse);
    expect(account?.email, testEmail);
  });

  group('linkEmail', () {
    SupabaseTestClient answering(Map<String, Object?> user) {
      final client = SupabaseTestClient(
        authHandler: (request) async =>
            request.method == 'PUT' && request.url.path == '/auth/v1/user'
            ? http.Response(
                jsonEncode(user),
                200,
                headers: {'content-type': 'application/json'},
              )
            : null,
      );
      addTearDown(client.client.dispose);
      return client;
    }

    final guestUser = anonymousSessionJson()['user']! as Map<String, Object?>;

    test(
      'sends email and password in one call; same id, no longer a guest',
      () async {
        final linked = answering({
          ...guestUser,
          'email': 'new@test.com',
          'is_anonymous': false,
        });
        await linked.signIn(); // any session: updateUser needs one
        final repo = SupabaseAccountRepository(linked.client);

        final account = await repo.linkEmail(
          email: 'new@test.com',
          password: 'long-enough',
        );

        expect(account, const Account(id: testUserId, email: 'new@test.com'));
        final put = linked.authRequests.singleWhere((r) => r.method == 'PUT');
        // gotrue also sends PKCE fields (null here): check only ours.
        final body = jsonDecode(put.body) as Map<String, Object?>;
        expect(body['email'], 'new@test.com');
        expect(body['password'], 'long-enough');
      },
    );

    test('email confirmation required: null, nothing linked yet', () async {
      final pending = answering({...guestUser, 'new_email': 'new@test.com'});
      await pending.signIn();
      final repo = SupabaseAccountRepository(pending.client);

      expect(
        await repo.linkEmail(email: 'new@test.com', password: 'long-enough'),
        isNull,
      );
    });
  });

  group('errors mapped to AccountException', () {
    /// Current Supabase Auth format: API version header, code in `code`
    /// (before 2024: `error_code`).
    Future<http.Response> Function(http.Request) refuse(
      int status,
      String code,
    ) =>
        (_) async => http.Response(
          jsonEncode({'code': code, 'msg': 'message serveur ($code)'}),
          status,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
        );

    Future<AccountFailure> failureOf(Future<Object?> Function() call) async {
      try {
        await call();
      } on AccountException catch (e) {
        return e.failure;
      }
      fail('AccountException attendue');
    }

    final cases = {
      (400, 'invalid_credentials'): AccountFailure.invalidCredentials,
      (400, 'email_not_confirmed'): AccountFailure.emailNotConfirmed,
      (422, 'user_already_exists'): AccountFailure.emailAlreadyUsed,
      // What linking a guest to a taken email answers (checked on the real
      // project, 19 Nov 2026).
      (422, 'email_exists'): AccountFailure.emailAlreadyUsed,
      (422, 'weak_password'): AccountFailure.weakPassword,
      (400, 'email_address_invalid'): AccountFailure.invalidInput,
      (429, 'over_request_rate_limit'): AccountFailure.rateLimited,
      (400, 'code_jamais_vu'): AccountFailure.unknown,
    };
    for (final MapEntry(key: (status, code), value: expected)
        in cases.entries) {
      test('$code → ${expected.name}', () async {
        final refusing = SupabaseTestClient(authHandler: refuse(status, code));
        addTearDown(refusing.client.dispose);
        final repo = SupabaseAccountRepository(refusing.client);

        expect(
          await failureOf(() => repo.signIn(email: testEmail, password: 'x')),
          expected,
        );
      });
    }

    // Linking needs a session: only the update itself is refused.
    for (final (status, code, expected) in [
      (422, 'email_exists', AccountFailure.emailAlreadyUsed),
      (422, 'weak_password', AccountFailure.weakPassword),
      (400, 'email_address_invalid', AccountFailure.invalidInput),
    ]) {
      test('linkEmail: $code → ${expected.name}', () async {
        final refusing = SupabaseTestClient(
          authHandler: (request) async =>
              request.method == 'PUT' && request.url.path == '/auth/v1/user'
              ? refuse(status, code)(request)
              : null,
        );
        addTearDown(refusing.client.dispose);
        await refusing.signIn();
        final repo = SupabaseAccountRepository(refusing.client);

        expect(
          await failureOf(
            () => repo.linkEmail(email: testEmail, password: 'x'),
          ),
          expected,
        );
      });
    }

    test('network unavailable → network', () async {
      final offline = SupabaseTestClient(
        authHandler: (_) async =>
            throw http.ClientException('Failed host lookup'),
      );
      addTearDown(offline.client.dispose);
      final repo = SupabaseAccountRepository(offline.client);

      expect(
        await failureOf(() => repo.signIn(email: testEmail, password: 'x')),
        AccountFailure.network,
      );
      expect(await failureOf(repo.signInAnonymously), AccountFailure.network);
    });

    test('anonymous sign-in rate limited → rateLimited', () async {
      final limited = SupabaseTestClient(
        authHandler: refuse(429, 'over_request_rate_limit'),
      );
      addTearDown(limited.client.dispose);
      final repo = SupabaseAccountRepository(limited.client);

      expect(
        await failureOf(repo.signInAnonymously),
        AccountFailure.rateLimited,
      );
    });

    test('anonymous sign-ins disabled in the project → unknown', () async {
      final disabled = SupabaseTestClient(
        authHandler: refuse(422, 'anonymous_provider_disabled'),
      );
      addTearDown(disabled.client.dispose);
      final repo = SupabaseAccountRepository(disabled.client);

      expect(await failureOf(repo.signInAnonymously), AccountFailure.unknown);
    });

    test('server error (5xx) → network', () async {
      final failing = SupabaseTestClient(
        authHandler: (_) async => http.Response('upstream error', 503),
      );
      addTearDown(failing.client.dispose);
      final repo = SupabaseAccountRepository(failing.client);

      expect(
        await failureOf(() => repo.signIn(email: testEmail, password: 'x')),
        AccountFailure.network,
      );
    });
  });
}
