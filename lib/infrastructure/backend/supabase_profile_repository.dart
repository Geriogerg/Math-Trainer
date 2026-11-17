import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/account/player_profile.dart';
import '../../core/domain/account/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Personne n\'est connecté.');
    return id;
  }

  @override
  Future<PlayerProfile> currentProfile() async {
    final userId = _requireUserId;
    try {
      // `maybeSingle` et non `single` : aucune ligne n'existe tant que le
      // joueur n'a jamais choisi de nom (pas de trigger à l'inscription,
      // `supabase/profiles.sql`) — `single` lèverait alors une erreur au lieu
      // d'un profil sans nom.
      final row = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return PlayerProfile(
        accountId: userId,
        displayName: row?['display_name'] as String?,
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    final userId = _requireUserId;
    try {
      // `upsert` et non `update` : le premier nom choisi crée la ligne — un
      // `update` sur une ligne absente ne modifie rien, sans erreur.
      await _client.from('profiles').upsert({
        'id': userId,
        'display_name': displayName,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
