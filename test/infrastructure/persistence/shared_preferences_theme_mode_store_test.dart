import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/core/domain/persistence/theme_mode_store.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_theme_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesThemeModeStore', () {
    test('load() renvoie null tant que rien n\'a été enregistré', () async {
      final store = SharedPreferencesThemeModeStore();

      expect(await store.load(), isNull);
    });

    test('save() puis load() retrouve la préférence enregistrée', () async {
      final store = SharedPreferencesThemeModeStore();

      await store.save(ThemeModePreference.dark);
      final result = await store.load();

      expect(result, ThemeModePreference.dark);
    });

    test('persiste au-delà de l\'instance du store', () async {
      await SharedPreferencesThemeModeStore().save(ThemeModePreference.light);

      final result = await SharedPreferencesThemeModeStore().load();

      expect(result, ThemeModePreference.light);
    });
  });
}
