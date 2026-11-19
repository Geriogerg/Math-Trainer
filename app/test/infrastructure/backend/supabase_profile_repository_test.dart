import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:math_core/account/player_profile.dart';
import 'package:math_trainer/infrastructure/backend/supabase_profile_repository.dart';

import 'supabase_test_client.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'currentProfile without a stored row returns a profile without a name, not an error',
    () async {
      final supabase = SupabaseTestClient(restHandler: (_) async => _json([]));
      addTearDown(supabase.client.dispose);
      await supabase.signIn();

      final profile = await SupabaseProfileRepository(
        supabase.client,
      ).currentProfile();

      expect(profile, const PlayerProfile(accountId: testUserId));
    },
  );

  test('currentProfile reads the stored name', () async {
    final supabase = SupabaseTestClient(
      restHandler: (_) async => _json([
        {'id': testUserId, 'display_name': 'Alex'},
      ]),
    );
    addTearDown(supabase.client.dispose);
    await supabase.signIn();

    final profile = await SupabaseProfileRepository(
      supabase.client,
    ).currentProfile();

    expect(
      profile,
      const PlayerProfile(accountId: testUserId, displayName: 'Alex'),
    );
  });

  // Regression: an `update` on a missing row changed nothing, without an
  // error — the first chosen name was silently lost.
  test(
    'updateDisplayName creates or replaces the row (upsert on the id key)',
    () async {
      final supabase = SupabaseTestClient(
        restHandler: (_) async => http.Response('', 201),
      );
      addTearDown(supabase.client.dispose);
      await supabase.signIn();

      await SupabaseProfileRepository(
        supabase.client,
      ).updateDisplayName('Alex');

      final request = supabase.restRequests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/profiles');
      expect(
        request.headers['Prefer'],
        contains('resolution=merge-duplicates'),
      );
      expect(jsonDecode(request.body), {
        'id': testUserId,
        'display_name': 'Alex',
      });
    },
  );

  test('currentProfile throws an Exception if nobody is signed in', () {
    final supabase = SupabaseTestClient(restHandler: (_) async => _json([]));
    addTearDown(supabase.client.dispose);

    expect(
      SupabaseProfileRepository(supabase.client).currentProfile(),
      throwsA(isA<Exception>()),
    );
  });
}
