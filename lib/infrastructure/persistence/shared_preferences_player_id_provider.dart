import 'package:shared_preferences/shared_preferences.dart';

import '../../core/domain/persistence/local_player_id_provider.dart';
import '../../core/domain/persistence/uuid.dart';

/// Id generated once on the first call, then read back. Since accounts,
/// it is no longer the screens' `playerId` — see [LocalPlayerIdProvider].
class SharedPreferencesPlayerIdProvider implements LocalPlayerIdProvider {
  static const _key = 'local_player_id';

  @override
  Future<String> currentPlayerId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null) return existing;

    final generated = generateUuidV4();
    await prefs.setString(_key, generated);
    return generated;
  }
}
