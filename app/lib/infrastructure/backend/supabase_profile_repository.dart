import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:math_core/account/display_name.dart';
import 'package:math_core/account/player_profile.dart';
import 'package:math_core/account/profile_repository.dart';

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
        underReview: await _underReview(),
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Whether the owner hid or suspended the account
  /// (`my_account_under_review()`, Phase 6a). Best effort: a failure here
  /// must not hide the player's name.
  Future<bool> _underReview() async {
    try {
      return await _client.rpc('my_account_under_review') == true;
    } on PostgrestException {
      return false;
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
      // 23514: a check constraint — the name rule (or its length).
      if (e.code == '23514') throw const DisplayNameRefused();
      // 23505: the unique index — the name, or one that reads the same,
      // is held by another player (Phase 6a).
      if (e.code == '23505') throw const DisplayNameTaken();
      throw Exception(e.message);
    }
  }
}
