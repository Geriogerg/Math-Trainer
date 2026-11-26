import 'package:math_core/friends/friends.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Friends on Supabase (`supabase/migrations/…_friends.sql`): security
/// definer functions on the caller's own account, linked players only.
class SupabaseFriendsRepository implements FriendsRepository {
  SupabaseFriendsRepository(this._client);

  final SupabaseClient _client;

  Future<Object?> _call(String name, [Map<String, Object?>? params]) async {
    try {
      return await _client.rpc(name, params: params);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<String> myCode() async => '${await _call('my_friend_code')}';

  @override
  Future<String> newCode() async => '${await _call('new_friend_code')}';

  @override
  Future<FriendRequestOutcome> request(String code) async =>
      FriendRequestOutcome.parse(
        await _call('friend_request', {'p_code': code}),
      );

  @override
  Future<List<FriendRequest>> incoming() async =>
      friendRequestsFromJson(await _call('friend_requests_incoming'));

  @override
  Future<void> respond(String fromId, {required bool accept}) async =>
      _call('friend_respond', {'p_from': fromId, 'p_accept': accept});

  @override
  Future<void> remove(String friendId) async =>
      _call('friend_remove', {'p_friend': friendId});

  @override
  Future<List<Friend>> friends() async =>
      friendsFromJson(await _call('friend_list'));

  @override
  Future<List<FriendDuel>> history(String friendId) async =>
      friendHistoryFromJson(
        await _call('friend_history', {'p_friend': friendId}),
      );
}
