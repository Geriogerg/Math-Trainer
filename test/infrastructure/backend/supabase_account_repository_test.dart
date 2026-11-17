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

  test('authState émet null au démarrage sans session', () async {
    supabase.emitInitialSessionWithoutUser();
    expect(await repository.authState.first, isNull);
  });

  // Garde-fou de bibliothèque : `ProfileScreen` lit le compte par
  // `authState.first`. Ça ne tient que parce que `onAuthStateChange` rejoue
  // le dernier événement seulement (pas tout l'historique, malgré le nom
  // `ReplaySubject`). Si une mise à jour de Supabase changeait ce point,
  // `.first` renverrait `initialSession` (aucun compte) après toute
  // connexion faite pendant le lancement en cours.
  test(
    'authState.first donne le compte courant après une connexion faite pendant ce lancement',
    () async {
      supabase.emitInitialSessionWithoutUser();
      await supabase.signIn();

      expect(await repository.authState.first, _account);
    },
  );

  test(
    'un nouvel abonné ne rejoue pas l\'état déconnecté de l\'historique',
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

  test('authState suit la connexion puis la déconnexion', () async {
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

  test('déconnexion hors ligne : déconnecté localement, sans erreur', () async {
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

  group('erreurs traduites en AccountException', () {
    /// Format actuel de Supabase Auth : en-tête de version d'API, code dans
    /// `code` (avant 2024 : `error_code`).
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
        expect(
          await failureOf(() => repo.signUp(email: testEmail, password: 'x')),
          expected,
        );
      });
    }

    test('réseau indisponible → network', () async {
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
    });

    test('serveur en erreur (5xx) → network', () async {
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
