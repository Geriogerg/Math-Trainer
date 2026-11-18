import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/account/player_profile.dart';
import '../../core/domain/account/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Nobody is signed in.');
    return id;
  }

  @override
  Future<PlayerProfile> currentProfile() async {
    final userId = _requireUserId;
    try {
      // `maybeSingle`, not `single`: no row exists until the player has
      // chosen a name (no sign-up trigger, `supabase/profiles.sql`) —
      // `single` would then throw instead of returning a profile without a
      // name.
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
      // `upsert`, not `update`: the first chosen name creates the row — an
      // `update` on a missing row changes nothing, without an error.
      await _client.from('profiles').upsert({
        'id': userId,
        'display_name': displayName,
      });
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
