import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/friends/friends.dart';

/// The invite link's code, until the request is sent.
class SharedPreferencesPendingInviteStore implements PendingInviteStore {
  const SharedPreferencesPendingInviteStore();

  static const _key = 'pending_friend_invite';

  @override
  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> save(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    if (code == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, code);
    }
  }
}
