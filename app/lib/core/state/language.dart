/// The interface's language (Phase 6d, plan v4.2): English and French.
/// Stored by its [code]: never change one.
enum AppLanguage {
  english('en'),
  french('fr');

  const AppLanguage(this.code);

  /// The language's ISO 639-1 code: the stored value, the page's `lang`,
  /// the locale Flutter's own words follow.
  final String code;

  /// The browser's language decides until the player chooses: French for
  /// any French locale (fr, fr-FR, fr-CA…), English otherwise.
  static AppLanguage forLocale(String languageCode) =>
      languageCode.toLowerCase() == 'fr' ? french : english;

  /// The language stored as [code]; `null` for nothing or an unknown code.
  static AppLanguage? byCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}

/// The language the player chose in Profile, remembered on the device;
/// none until they choose (the browser's then applies).
abstract interface class LanguageStore {
  Future<AppLanguage?> load();

  Future<void> save(AppLanguage language);
}
