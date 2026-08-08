import 'package:shared_preferences/shared_preferences.dart';

import '../../core/domain/persistence/local_player_id_provider.dart';
import '../../core/domain/persistence/uuid.dart';

/// Un seul profil implicite par appareil aujourd'hui : l'id est généré une
/// fois au premier appel puis relu ensuite. Les vrais comptes utilisateurs
/// remplaceront ce mécanisme, pas avant.
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
