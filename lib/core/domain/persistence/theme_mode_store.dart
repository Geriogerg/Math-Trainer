/// Two values only: the system mode is not a remembered choice, it is the
/// default as long as nothing has been stored (`load() == null`, same
/// convention as `TypeSelectionStore`).
enum ThemeModePreference { light, dark }

/// Remembers the manual day/night toggle between app launches — concrete
/// implementation (shared_preferences) in `infrastructure/`, never in the
/// domain (rule 3).
abstract class ThemeModeStore {
  /// `null`: never chosen explicitly, the caller falls back to the system theme.
  Future<ThemeModePreference?> load();

  Future<void> save(ThemeModePreference preference);
}
