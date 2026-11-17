import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:math_trainer/core/domain/account/player_profile.dart';
import 'package:math_trainer/infrastructure/backend/supabase_profile_repository.dart';

import 'supabase_test_client.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'currentProfile sans ligne en base renvoie un profil sans nom, pas une erreur',
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

  test('currentProfile lit le nom enregistré', () async {
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

  // Régression : un `update` sur une ligne absente ne modifiait rien, sans
  // erreur — le premier nom choisi était perdu en silence.
  test(
    'updateDisplayName crée ou remplace la ligne (upsert sur la clé id)',
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
      expect(request.headers['Prefer'], contains('resolution=merge-duplicates'));
      expect(jsonDecode(request.body), {
        'id': testUserId,
        'display_name': 'Alex',
      });
    },
  );

  test('currentProfile lève une Exception si personne n\'est connecté', () {
    final supabase = SupabaseTestClient(restHandler: (_) async => _json([]));
    addTearDown(supabase.client.dispose);

    expect(
      SupabaseProfileRepository(supabase.client).currentProfile(),
      throwsA(isA<Exception>()),
    );
  });
}
