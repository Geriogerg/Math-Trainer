import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/hints.dart';

/// Each hint seen, as a flag under its own key.
class SharedPreferencesHintsStore implements HintsStore {
  const SharedPreferencesHintsStore();

  static String _key(Hint hint) => 'hint_seen_${hint.name}';

  @override
  Future<bool> seen(Hint hint) async =>
      (await SharedPreferences.getInstance()).getBool(_key(hint)) ?? false;

  @override
  Future<void> markSeen(Hint hint) async =>
      (await SharedPreferences.getInstance()).setBool(_key(hint), true);
}
