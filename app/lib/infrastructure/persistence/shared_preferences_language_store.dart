import 'package:shared_preferences/shared_preferences.dart';

import '../../core/state/language.dart';

/// The chosen language in `shared_preferences` (on the web `localStorage`,
/// key `flutter.language`: the loading screen reads it too, `index.html`).
class SharedPreferencesLanguageStore implements LanguageStore {
  const SharedPreferencesLanguageStore();

  static const key = 'language';

  @override
  Future<AppLanguage?> load() async => AppLanguage.byCode(
    (await SharedPreferences.getInstance()).getString(key),
  );

  @override
  Future<void> save(AppLanguage language) async =>
      (await SharedPreferences.getInstance()).setString(key, language.code);
}
