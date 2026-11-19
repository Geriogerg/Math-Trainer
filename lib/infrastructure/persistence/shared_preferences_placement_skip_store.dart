import 'package:shared_preferences/shared_preferences.dart';

import '../../core/domain/persistence/placement_skip_store.dart';

/// One boolean key per player id: a guest who signs in to another account
/// on this device does not hand the skip over.
class SharedPreferencesPlacementSkipStore implements PlacementSkipStore {
  const SharedPreferencesPlacementSkipStore();

  static String _key(String playerId) => 'placement_skipped.$playerId';

  @override
  Future<bool> hasSkipped(String playerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(playerId)) ?? false;
  }

  @override
  Future<void> markSkipped(String playerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(playerId), true);
  }
}
