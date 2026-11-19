import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/persistence/theme_mode_store.dart';

class SharedPreferencesThemeModeStore implements ThemeModeStore {
  const SharedPreferencesThemeModeStore();

  static const _key = 'theme_mode_preference';

  @override
  Future<ThemeModePreference?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return null;
    return ThemeModePreference.values.byName(stored);
  }

  @override
  Future<void> save(ThemeModePreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, preference.name);
  }
}
