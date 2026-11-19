import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/persistence/theme_mode_store.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesThemeModeStore', () {
    test('load() returns null until something is saved', () async {
      final store = SharedPreferencesThemeModeStore();

      expect(await store.load(), isNull);
    });

    test('save() then load() finds the saved preference', () async {
      final store = SharedPreferencesThemeModeStore();

      await store.save(ThemeModePreference.dark);
      final result = await store.load();

      expect(result, ThemeModePreference.dark);
    });

    test('persists beyond the store instance', () async {
      await SharedPreferencesThemeModeStore().save(ThemeModePreference.light);

      final result = await SharedPreferencesThemeModeStore().load();

      expect(result, ThemeModePreference.light);
    });
  });
}
