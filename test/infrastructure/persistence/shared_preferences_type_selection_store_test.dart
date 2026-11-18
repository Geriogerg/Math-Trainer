import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_type_selection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesTypeSelectionStore', () {
    test('load() returns null until something is saved', () async {
      final store = SharedPreferencesTypeSelectionStore();

      expect(await store.load(), isNull);
    });

    test('save() then load() finds exactly the saved types', () async {
      final store = SharedPreferencesTypeSelectionStore();

      await store.save({ExerciseType.multiplication, ExerciseType.division});
      final result = await store.load();

      expect(result, {ExerciseType.multiplication, ExerciseType.division});
    });

    test('an empty selection saved explicitly is distinct from "never saved"', () async {
      final store = SharedPreferencesTypeSelectionStore();

      await store.save(const {});
      final result = await store.load();

      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('persists beyond the store instance', () async {
      await SharedPreferencesTypeSelectionStore().save({ExerciseType.percentage});

      final result = await SharedPreferencesTypeSelectionStore().load();

      expect(result, {ExerciseType.percentage});
    });
  });
}
