import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_trainer/infrastructure/backend/supabase_account_repository.dart';
import 'package:math_trainer/infrastructure/backend/supabase_online_repository.dart';
import 'package:math_trainer/infrastructure/backend/time_limited_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every Supabase call gives up (Phase 6b commit 5, review M18).
void main() {
  test('the limit is the plan\'s 15–20 s', () {
    expect(supabaseCallLimit, const Duration(seconds: 15));
  });

  test('an answer in time passes through', () async {
    final client = TimeLimitedClient(
      MockClient((_) async => http.Response('ok', 200)),
      limit: const Duration(seconds: 1),
    );
    expect((await client.get(Uri.parse('https://db.test/rest'))).body, 'ok');
  });

  test('no answer: fails as an offline request does', () async {
    final never = Completer<http.Response>();
    final client = TimeLimitedClient(
      MockClient((_) => never.future),
      limit: const Duration(milliseconds: 20),
    );
    await expectLater(
      client.post(Uri.parse('https://db.test/rest/v1/rpc/duel_overview')),
      throwsA(isA<http.ClientException>()),
    );
  });

  group('through Supabase: the error states the screens already show', () {
    late SupabaseClient supabase;

    setUp(() {
      final never = Completer<http.Response>();
      supabase = SupabaseClient(
        'https://test-project.supabase.co',
        'sb_publishable_test',
        httpClient: TimeLimitedClient(
          MockClient((_) => never.future),
          limit: const Duration(milliseconds: 20),
        ),
      );
    });

    tearDown(() => supabase.dispose());

    Future<AccountFailure?> failureOf(Future<void> Function() call) async {
      try {
        await call();
      } on AccountException catch (e) {
        return e.failure;
      }
      return null;
    }

    test('a sign-in with no answer: network', () async {
      final accounts = SupabaseAccountRepository(supabase);
      expect(
        await failureOf(accounts.signInAnonymously),
        AccountFailure.network,
      );
    });

    test('account deletion with no answer: network, never a spinner for '
        'ever (review M18)', () async {
      final accounts = SupabaseAccountRepository(supabase);
      expect(await failureOf(accounts.deleteAccount), AccountFailure.network);
    });

    test('a database read with no answer throws (the tab offers Retry)', () {
      expect(
        SupabaseOnlineRepository(supabase).overview(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
